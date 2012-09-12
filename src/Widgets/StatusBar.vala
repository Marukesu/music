// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2012 Noise Developers (http://launchpad.net/noise)
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * The Noise authors hereby grant permission for non-GPL compatible
 * GStreamer plugins to be used and distributed together with GStreamer
 * and Noise. This permission is above and beyond the permissions granted
 * by the GPL license by which Noise is covered. If you modify this code
 * you may extend this exception to your version of the code, but you are not
 * obligated to do so. If you do not wish to do so, delete this exception
 * statement from your version.
 */

public class Noise.Widgets.StatusBar : Granite.Widgets.StatusBar {

    public StatusBar (LibraryWindow lw) {
        insert_widget (new AddPlaylistChooser (), true);
        insert_widget (new ShuffleChooser (), true);
        insert_widget (new RepeatChooser (), true);
        insert_widget (new EqualizerChooser ());
        insert_widget (new InfoPanelChooser ());
    }

    public void set_info (string message) {
        set_text (message);
    }
}


/**
 * STATUSBAR ITEMS
 */


private class Noise.RepeatChooser : Noise.SimpleOptionChooser {

    public RepeatChooser () {
        var repeat_on_image = Icons.REPEAT_ON.render_image (Gtk.IconSize.MENU);
        var repeat_one_image = Icons.REPEAT_ONE.render_image (Gtk.IconSize.MENU);
        var repeat_off_image = Icons.REPEAT_OFF.render_image (Gtk.IconSize.MENU);

        // MUST follow the exact same order of Noise.Player.Repeat
        appendItem (_("Off"), repeat_off_image, _("Enable Repeat"));
        appendItem (_("Song"), repeat_one_image, _("Repeat Song"));
        appendItem (_("Album"), repeat_on_image, _("Repeat Album"));
        appendItem (_("Artist"), repeat_on_image, _("Repeat Artist"));
        appendItem (_("All"), repeat_on_image, _("Repeat All"));

        update_option ();

        option_changed.connect (on_option_changed);
        App.player.notify["repeat"].connect (update_option);
    }

    private void update_option () {
        setOption ((int)App.player.repeat);
    }

    private void on_option_changed () {
        int val = current_option;

        if ((int)App.player.repeat == val)
            return;

        App.player.repeat = (Noise.Player.Repeat)val;
    }
}


private class Noise.ShuffleChooser : Noise.SimpleOptionChooser {

    public ShuffleChooser () {
        var shuffle_on_image   = Icons.SHUFFLE_ON.render_image (Gtk.IconSize.MENU);
        var shuffle_off_image  = Icons.SHUFFLE_OFF.render_image (Gtk.IconSize.MENU);

        appendItem (_("Off"), shuffle_off_image, _("Enable Shuffle"));
        appendItem (_("All"), shuffle_on_image, _("Disable Shuffle"));

        update_mode ();

        option_changed.connect (on_option_changed);
        App.player.notify["shuffle"].connect (update_mode);
    }

    private void update_mode () {
        setOption ((int)App.player.shuffle);
    }

    private void on_option_changed () {
        int val = current_option;

        if ((int)App.player.shuffle == val)
            return;

        App.player.setShuffleMode ((Player.Shuffle)val, true);
    }
}

#if HAVE_ADD_PLAYLIST_AS_BUTTON
private class Noise.AddPlaylistChooser : Gtk.Button {
#else
private class Noise.AddPlaylistChooser : Gtk.EventBox {
#endif

    private Gtk.Menu menu;

    public AddPlaylistChooser () {
        margin_right = 12;

        tooltip_text = _("Add Playlist");

#if HAVE_ADD_PLAYLIST_AS_BUTTON
        relief = Gtk.ReliefStyle.NONE;
#else
        visible_window = false;
        above_child = true;
#endif

        add (Icons.render_image ("list-add-symbolic", Gtk.IconSize.MENU));

        var add_pl_menuitem = new Gtk.MenuItem.with_label (_("Add Playlist"));
        var add_spl_menuitem = new Gtk.MenuItem.with_label (_("Add Smart Playlist"));

        menu = new Gtk.Menu ();
        menu.append (add_pl_menuitem);
        menu.append (add_spl_menuitem);
        menu.show_all ();

        add_pl_menuitem.activate.connect ( () => {
            App.main_window.sideTree.playlistMenuNewClicked ();
        });

        add_spl_menuitem.activate.connect ( () => {
            App.main_window.sideTree.smartPlaylistMenuNewClicked ();
        });
    }

#if HAVE_ADD_PLAYLIST_AS_BUTTON
    public override void clicked () {
        menu.popup (null, null, null, Gdk.BUTTON_PRIMARY, Gtk.get_current_event_time ());
    }
#else
    public override bool button_press_event (Gdk.EventButton event) {
        if (event.type == Gdk.EventType.BUTTON_PRESS) {
            menu.popup (null, null, null, Gdk.BUTTON_SECONDARY, event.time);
            return true;
        }

        return false;
    }
#endif
}


private class Noise.EqualizerChooser : Noise.SimpleOptionChooser {

    private Gtk.Window? equalizer_window = null;

    public EqualizerChooser () {
        var eq_show_image = Icons.EQ_SYMBOLIC.render_image (Gtk.IconSize.MENU);
        var eq_hide_image = Icons.EQ_SYMBOLIC.render_image (Gtk.IconSize.MENU);

        appendItem (_("Hide"), eq_show_image, _("Show Equalizer"));
        appendItem (_("Show"), eq_hide_image, _("Hide Equalizer"));

        setOption (0);

        option_changed.connect (eq_option_chooser_clicked);
    }

    private void eq_option_chooser_clicked () {
        int val = current_option;

        if (equalizer_window == null && val == 1) {
            equalizer_window = new EqualizerWindow (App.library_manager, App.main_window);
            equalizer_window.show_all ();
            equalizer_window.destroy.connect ( () => {
                // revert the option to "Hide equalizer" after the window is destroyed
                setOption (0);
            });
        }
        else if (val == 0 && equalizer_window != null) {
            equalizer_window.destroy ();
            equalizer_window = null;
        }
    }
}


private class Noise.InfoPanelChooser : Noise.SimpleOptionChooser {

    public InfoPanelChooser () {
        var info_panel_show = Icons.PANE_SHOW_SYMBOLIC.render_image (Gtk.IconSize.MENU);
        var info_panel_hide = Icons.PANE_HIDE_SYMBOLIC.render_image (Gtk.IconSize.MENU);

        appendItem (_("Hide"), info_panel_show, _("Show Info Panel"));
        appendItem (_("Show"), info_panel_hide, _("Hide Info Panel"));

        on_info_panel_visibility_change ();
        App.main_window.info_panel.show.connect (on_info_panel_visibility_change);
        App.main_window.info_panel.hide.connect (on_info_panel_visibility_change);

        option_changed.connect (on_option_changed);
    }

    private void on_info_panel_visibility_change () {
        setOption (App.main_window.info_panel.visible ? 1 : 0);
    }

    private void on_option_changed (bool by_user) {
        int val = current_option;

        bool visible = val == 1;
        App.main_window.info_panel.visible = visible;

        // We write the new state to settings in this method as this is the only user-facing widget
        // for hiding and showing the context pane. Any other visibility change we do internally
        // or elsewhere should not be saved
        if (by_user)
            Settings.SavedState.instance.more_visible = visible;
    }
}
