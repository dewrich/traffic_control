package Utils::Helper::ValidationHelper;
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

use Carp qw(cluck confess);
use Data::Dumper;
use Time::Local;

sub new {
	my $self  = {};
	my $class = shift;
	my $args  = shift;

	return ( bless( $self, $class ) );
}

sub validation_errors_to_alerts {
	my $self   = shift;
	my $errors = shift;

	my $error_count = scalar @$errors;
	my @alerts;
	foreach my $error (@$errors) {
		my $alert;

		if ( defined( $error->{path} ) ) {
			$alert->{path} = $error->{path};
		}
		my $message = $error->{message};

		# trim the message to prevent exposing code line numbers from Perl
		$message =~ s,^(.{90}).+,$1...,g;
		$alert->{text} = $message;
		push( @alerts, $alert );
	}
	return \@alerts;
}
1;
