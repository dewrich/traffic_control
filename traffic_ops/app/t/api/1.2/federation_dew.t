package main;

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
use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use DBI;
use Schema;
use strict;
use warnings;
use JSON;
use Test::TestHelper;
use Fixtures::TmUser;
use Fixtures::Federation;
use Fixtures::FederationDeliveryservice;
use Fixtures::FederationResolver;
use Fixtures::FederationFederationResolver;
use Fixtures::FederationTmuser;
use Data::Dumper;

BEGIN { $ENV{MOJO_MODE} = "test" }

my $t      = Test::Mojo->new('TrafficOps');
my $dbh    = Schema->database_handle;
my $schema = Schema->connect_to_database;

#unload data for a clean test
Test::TestHelper->unload_core_data($schema);
Test::TestHelper->teardown( $schema, 'Federation' );
Test::TestHelper->teardown( $schema, 'FederationDeliveryservice' );
Test::TestHelper->teardown( $schema, 'FederationFederationResolver' );
Test::TestHelper->teardown( $schema, 'FederationResolver' );

#load core test data
Test::TestHelper->load_core_data($schema);

my $schema_values = { schema => $schema, no_transactions => 1 };
#
# FederationResolver
#
my $federation_resolver = Fixtures::FederationResolver->new($schema_values);
Test::TestHelper->load_all_fixtures($federation_resolver);
#
# FederationMapping
#
my $federation = Fixtures::Federation->new($schema_values);
Test::TestHelper->load_all_fixtures($federation);

# FederationDeliveryservice
#
my $fmd = Fixtures::FederationDeliveryservice->new($schema_values);
Test::TestHelper->load_all_fixtures($fmd);

my $federation_federation_resolver = Fixtures::FederationFederationResolver->new($schema_values);
Test::TestHelper->load_all_fixtures($federation_federation_resolver);

my $ft = Fixtures::FederationTmuser->new($schema_values);
Test::TestHelper->load_all_fixtures($ft);

ok $t->post_ok( '/login', => form => { u => 'federation', p => Test::TestHelper::FEDERATION_USER_PASSWORD } )->status_is(302)
	->or( sub { diag $t->tx->res->content->asset->{content}; } );

ok $t->get_ok("/internal/api/1.2/federations.json")->status_is(200)->or( sub { diag $t->tx->res->content->asset->{content}; } )
	->json_is( "/response/0/deliveryService", "test-ds1" )->json_is( "/response/0/mappings/0/cname", "cname1." )
	->json_is( "/response/0/mappings/0/ttl", "86400" )->json_is( "/response/0/mappings/0/resolve6/0", "FE80::0202:B3FF:FE1E:8329/128" )
	->json_is( "/response/0/mappings/0/resolve4/0", "127.0.0.1/32" )

	->json_is( "/response/0/deliveryService", "test-ds1" )->json_is( "/response/0/mappings/1/cname", "cname2." )
	->json_is( "/response/0/mappings/1/ttl", "86400" )

	->json_is( "/response/1/deliveryService", "test-ds2" )->json_is( "/response/1/mappings/0/cname", "cname4." )
	->json_is( "/response/1/mappings/0/ttl", "86400" ), 'Simple Get';

my $federation_data = {
	federations => [
		{
			deliveryService => "xml_id",
			mappings        => [
				{
					cname    => "cname.",
					ttl      => 60,
					resolve4 => ["127.0.0.1/24"],
					resolve6 => [ "2001:558:6010::/48", "2001:558:1018:6::/64" ],
				}
			],

		}
	],
};

my $federation_json = encode_json($federation_data);

#diag( "federation_json #-> " . Dumper($federation_json) );

ok $t->post_ok( '/api/1.2/federations', json => $federation_json )->status_is(200)->or( sub { diag $t->tx->res->content->asset->{content}; } ),
	'Valid POST';

#diag( "federation_json #-> " . Dumper($federation_json) );

# Verify
$federation_data->{federations}->[0]->{mappings}->[0]->{ttl} = 2;
$federation_json = encode_json($federation_data);
ok $t->post_ok( '/api/1.2/federations', json => $federation_json )->status_is(400)->or( sub { diag $t->tx->res->content->asset->{content}; } ), 'ttl > 60';

$federation_data->{federations}->[0]->{mappings}->[0]->{cname} = "cname";
$federation_json = encode_json($federation_data);
ok $t->post_ok( '/api/1.2/federations', json => $federation_json )->status_is(400)->or( sub { diag $t->tx->res->content->asset->{content}; } ),
	'CNAME without ending period';

ok $t->post_ok( "/api/1.2/federations", json => undef )->status_is(400)->or( sub { diag $t->tx->res->content->asset->{content}; } )
	->json_is( "/alerts/0/text", "malformed JSON string, neither tag, array, object, number, string or atom, at character of...\n" ),
	'BAD POST with no data';

ok $t->post_ok("/api/1.2/federations")->status_is(400)->or( sub { diag $t->tx->res->content->asset->{content}; } ), 'BAD POST with no JSON data';
ok $t->get_ok('/logout')->status_is(302)->or( sub { diag $t->tx->res->content->asset->{content}; } );

#Test::TestHelper->teardown( $schema, 'Federation' );
#Test::TestHelper->teardown( $schema, 'FederationDeliveryservice' );
#Test::TestHelper->teardown( $schema, 'FederationFederationResolver' );
#Test::TestHelper->teardown( $schema, 'FederationResolver' );

$dbh->disconnect();
done_testing();
