package MusicBrainz::Server::ControllerBase::WS::1;

use Moose;
use Readonly;
BEGIN { extends 'MusicBrainz::Server::Controller'; }

use MusicBrainz::Server::Data::Utils qw( model_to_type );

use MusicBrainz::Server::WebService::XMLSerializerV1;

has 'model' => (
    isa => 'Str',
    is  => 'ro',
);

sub serializers {
    return {
        xml => 'MusicBrainz::Server::WebService::XMLSerializerV1',
    };
}

sub begin : Private {
    my ($self, $c) = @_;
    $c->stash->{data} = {};
    $self->validate($c, $self->serializers) or $c->detach('bad_req');
}

sub root : Chained('/') PathPart('ws/1') CaptureArgs(0) { }

sub search : Chained('root') PathPart('')
{
    my ($self, $c) = @_;

    my $limit = 0 + ($c->req->query_params->{limit} || 25);
    $limit = 25 if $limit < 1 || $limit > 100;

    my $offset = 0 + ($c->req->query_params->{offset} || 0);
    $offset = 0 if $offset < 0;

    $c->res->body(
        $c->model('Search')->xml_search(
            %{ $c->req->query_params },

            limit   => $limit,
            offset  => $offset,
            type    => model_to_type($self->model),
            version => 1,
        ));

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
}

# Don't render with TT
sub end : Private { }

sub load : Chained('root') PathPart('') CaptureArgs(1)
{
    my ($self, $c, $gid) = @_;

    if (!MusicBrainz::Server::Validation::IsGUID($gid))
    {
        $c->stash->{error} = "Invalid mbid.";
        $c->detach('bad_req');
    }

    my $entity = $c->model($self->model)->get_by_gid($gid)
        or $c->detach('not_found');

    $c->stash->{entity} = $entity;
}

sub bad_req : Private
{
    my ($self, $c) = @_;
    $c->res->status(400);
    $c->res->content_type("text/plain; charset=utf-8");
    $c->res->body($c->stash->{serializer}->output_error($c->stash->{error}.
                  "\nFor usage, please see: http://musicbrainz.org/development/mmd\015\012"));
    $c->detach;
}

sub not_found : Private
{
    my ($self, $c) = @_;
    $c->res->status(404);
    $c->detach;
}

no Moose;
1;

=head1 COPYRIGHT

Copyright (C) 2010 MetaBrainz Foundation

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=cut
