package API::Federation;
#
# Copyright 2015 Comcast Cable Communications Management, LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#
#

# JvD Note: you always want to put Utils as the first use. Sh*t don't work if it's after the Mojo lines.
use UI::Utils;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;
use Cwd;
use Net::CIDR;
use File::Find;
use File::Basename;
use JSON;
use JSON::Validator;
use Validate::Tiny ':all';
use Data::Validate::IP qw(is_ipv4 is_ipv6);

sub index {
	my $self             = shift;
	my $orderby          = $self->param('orderby') || "xml_id";
	my $current_username = $self->current_user()->{username};
	my $data;

	my $rs_data = $self->db->resultset('FederationDeliveryservice')->search(
		{},
		{
			prefetch => [ 'federation', 'deliveryservice' ],
			order_by => "deliveryservice." . $orderby
		}
	);

	if ( $rs_data->count() == 0 ) {
		return $self->success( {} );
	}

	while ( my $row = $rs_data->next ) {
		my $federation_id = $row->federation->id;
		my $user = $self->find_federation_tmuser( $current_username, $federation_id );
		if ( !defined $user ) {
			return $self->alert("You must be a Federation user to perform this operation!");
		}

		my $mapping;
		$mapping->{'cname'} = $row->federation->cname;
		$mapping->{'ttl'}   = $row->federation->ttl;

		my @resolvers = $self->db->resultset('FederationResolver')
			->search( { 'federation_federation_resolvers.federation' => $federation_id }, { prefetch => 'federation_federation_resolvers' } )->all();

		for my $resolver (@resolvers) {
			my $type = lc $resolver->type->name;
			if ( defined $mapping->{$type} ) {
				push( $mapping->{$type}, $resolver->ip_address );
			}
			else {
				@{ $mapping->{$type} } = ();
				push( $mapping->{$type}, $resolver->ip_address );
			}
		}

		my $xml_id = $row->deliveryservice->xml_id;
		if ( defined $data ) {
			my $ds = $self->find_delivery_service( $xml_id, $data );
			if ( !defined $ds ) {
				$data = $self->add_delivery_service( $xml_id, $mapping, $data );
			}
			else {
				$self->update_delivery_service( $ds, $mapping );
			}
		}
		else {
			$data = $self->add_delivery_service( $xml_id, $mapping, $data );
		}
	}
	$self->success($data);
}

sub find_federation_tmuser {
	my $self             = shift;
	my $current_username = shift;
	my $federation_id    = shift;
	my $user;

	my $tm_user = $self->find_tmuser($current_username);
	if ( defined $tm_user ) {
		$user = $self->db->resultset('FederationTmuser')->search(
			{
				tm_user    => $tm_user->id,
				federation => $federation_id,
				role       => $tm_user->role->id
			},
			{ prefetch => 'role' }
		)->single();
	}

	return $user;
}

sub find_delivery_service {
	my $self   = shift;
	my $xml_id = shift;
	my $data   = shift;
	my $ds;

	foreach my $service ( @{$data} ) {
		if ( $service->{'deliveryService'} eq $xml_id ) {
			$ds = $service;
		}
	}
	return $ds;
}

sub add_delivery_service {
	my $self   = shift;
	my $xml_id = shift;
	my $m      = shift;
	my $data   = shift;

	my $map;
	push( @{$map}, $m );
	push(
		@${data}, {
			"deliveryService" => $xml_id,
			"mappings"        => $map
		}
	);
	return $data;
}

sub update_delivery_service {
	my $self = shift;
	my $ds   = shift;
	my $m    = shift;

	my $map = $ds->{'mappings'};
	push( @{$map}, $m );
	$ds->{'mappings'} = $map;
}

sub add {
	my $self = shift;

	my $current_username = $self->current_user()->{username};
	my $user             = $self->find_tmuser($current_username);
	if ( !defined $user ) {
		return $self->alert("You must be an Federation user to perform this operation!");
	}
	my @errors      = $self->is_valid_schema();
	my $error_count = scalar @errors;
	$self->app->log->debug( "error_count #-> " . $error_count );
	$self->app->log->debug( "errors #-> " . Dumper(@errors) );
	if ( $error_count > 0 ) {
		my $alerts = $self->to_alerts(@errors);
		$self->app->log->debug( "alerts #-> " . Dumper($alerts) );
		return $self->alert($alerts);
	}
	else {
		return $self->success("Successfully created federations");
	}
}

sub to_alerts {
	my $self   = shift;
	my $errors = shift;
	my $alerts;
	foreach my $error (@$errors) {
		my $alert->{path} = $error->{path};
		$alert->{message} = $error->{message};
		push( @$alerts, $alert );
	}
	return \$alerts;
}

sub find_tmuser {
	my $self             = shift;
	my $current_username = shift;

	my $tm_user =
		$self->db->resultset('TmUser')->search( { username => $current_username, 'role.name' => 'federation' }, { prefetch => 'role' } )->single();

	return $tm_user;
}

sub add_federation_tmuser {
	my $self          = shift;
	my $tm_user       = shift;
	my $federation_id = shift;

	$self->db->resultset('FederationTmuser')->find_or_create(
		{
			federation => $federation_id,
			tm_user    => $tm_user->id,
			role       => $tm_user->role,
		}
	);
}

sub is_valid_schema {
	my $self = shift;

	my $json_request = $self->req->json;
	my $json         = decode_json($json_request);

	my $v       = JSON::Validator->new;
	my $formats = {
		cidr => sub { validate_cir(@_) }
	};
	$v->formats($formats);
	my $schema_file = $self->find_schema( 'v12', 'Federation.json' );
	$v->schema($schema_file);

	my @errors = $v->validate($json);
	return \@errors;
}

sub validate_cidr {
	return 'help';
}

sub find_schema {
	my $self        = shift;
	my $version     = shift;
	my $schema_file = shift;
	my $pwd         = cwd();

	my $mod_path = __PACKAGE__;
	$mod_path =~ s,::,/,g;
	$mod_path = $INC{ $mod_path . '.pm' };
	my $api_dir = dirname($mod_path);
	my $schema_file_path = sprintf( "%s/%s/%s/%s", $api_dir, '/Schema', $version, $schema_file );

	$self->app->log->debug( "schema_file_path #-> " . $schema_file_path );
	return $schema_file_path;
}

sub is_valid {
	my $self       = shift;
	my $federation = shift;

	my $rules = {
		fields => [qw/xml_id cname ttl/],

		checks => [
			[qw/xml_id cname ttl/] => is_required("is required"),

			cname => sub {
				my $value = shift;

				if ( is_ipv4($value) || is_ipv6($value) ) {
					return "records must always be pointed to another domain name, never to an IP-address. e.g. 'foo.example.com.'";
				}

				if ( $value !~ /\.$/ ) {
					return "records must have a trailing period. e.g. 'foo.example.com.'";
				}
			},
		]
	};

	my $result = validate( $federation, $rules );
	if ( $result->{success} ) {
		return ( 1, $result->{data} );
	}
	else {
		return ( 0, $result->{error} );
	}
}

sub add_federation {
	my $self        = shift;
	my $cname       = shift;
	my $ttl         = shift;
	my $description = shift;
	my $federation_id;

	my $federation = $self->db->resultset('Federation')->find_or_create(
		{
			cname       => $cname,
			ttl         => $ttl,
			description => $description
		}
	);
	if ( defined $federation ) {
		$federation_id = $federation->id;
	}
	return $federation_id;
}

sub add_federation_deliveryservice {
	my $self          = shift;
	my $federation_id = shift;
	my $xml_id        = shift;

	my $fd = $self->db->resultset('FederationDeliveryservice')->find_or_create(
		{
			federation      => $federation_id,
			deliveryservice => $self->db->resultset('Deliveryservice')->search( { xml_id => $xml_id } )->get_column('id')->single()
		}
	);
	return $fd;
}

sub add_resolver {
	my $self          = shift;
	my $resolvers     = shift;
	my $federation_id = shift;
	my $type_name     = shift;
	my $resolver;

	foreach my $r ( @{$resolvers} ) {
		for my $ip ($r) {
			my $valid_ip = Net::CIDR::cidrvalidate($ip);
			if ( !defined $valid_ip ) {
				next;
			}

			$resolver = $self->db->resultset('FederationResolver')->find_or_create(
				{
					ip_address => $ip,
					type       => $self->db->resultset('Type')->search( { name => $type_name } )->get_column('id')->single()
				}
			);

			if ( defined $resolver ) {
				$self->add_federation_federation_resolver( $federation_id, $resolver->id );
			}
		}
	}

	sub add_federation_federation_resolver {
		my $self          = shift;
		my $federation_id = shift;
		my $resolver_id   = shift;

		$self->db->resultset('FederationFederationResolver')->find_or_create(
			{
				federation          => $federation_id,
				federation_resolver => $resolver_id
			}
		);
	}
}

1;
