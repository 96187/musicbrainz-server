package MusicBrainz::Server::Controller::User::AdjustFlags;
use Moose;

BEGIN { extends 'MusicBrainz::Server::Controller' };

sub view : Chained('/user/base') PathPart('adjust-flags') RequireAuth
{
    my ($self, $c) = @_;

    my $user = $c->stash->{user};
    my $form = $c->form(
        form => 'User::AdjustFlags',
        item => {
            auto_editor     => $user->is_auto_editor,
            bot             => $user->is_bot,
            untrusted       => $user->is_untrusted,
            link_editor     => $user->is_relationship_editor,
            no_nag          => $user->is_nag_free,
            wiki_transcluder=> $user->is_wiki_transcluder,
            mbid_submitter  => $user->is_mbid_submitter,
            account_admin   => $user->is_account_admin,
        },
    );

    if (!$c->user->is_account_admin)
    {
        $c->detach('/error_401');
    }

    if ($c->form_posted && $form->process( params => $c->req->params )) {
        # When an admin views their own flags page the account admin checkbox will be disabled,
        # thus we need to manually insert a value here to keep the admin's privileges intact.
        $form->values->{account_admin} = 1 if ($c->user->id == $user->id);

        $c->model('Editor')->update_privileges($user, $form->values);

        $c->response->redirect($c->uri_for_action('/user/adjustflags/view', [ $user->name ]));
        $c->detach;
    }

    $c->stash(
        user => $user,
        form => $form,
        template => 'user/adjust_flags.tt',
    );
}

1;

=head1 COPYRIGHT

Copyright (C) 2010 Pavan Chander

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