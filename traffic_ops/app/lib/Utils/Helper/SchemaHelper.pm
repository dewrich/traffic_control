package Utils::Helper::SchemaHelper;
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
use File::Find;
use File::Basename;

sub new {
	my $self  = {};
	my $class = shift;
	my $args  = shift;

	return ( bless( $self, $class ) );
}

sub find_schema {
	my $self        = shift;
	my $version     = shift;
	my $schema_file = shift;

	my $mod_path = __PACKAGE__;
	$mod_path =~ s,::,/,g;
	print "mod_path #-> (" . $mod_path . ")\n";

	$mod_path = $INC{ $mod_path . '.pm' };
	my $lib_dir = dirname( dirname( dirname($mod_path) ) );

	return sprintf( "%s/%s/%s/%s/%s", $lib_dir, 'API', 'Schema', $version, $schema_file );

}
1;
