/*-
 * Copyright (c) 2011-2012       Scott Ringwelski <sgringwe@mtu.edu>
 *
 * Originally Written by Scott Ringwelski for BeatBox Music Player
 * BeatBox Music Player: http://www.launchpad.net/beat-box
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
 * Authored by: Scott Ringwelski <sgringwe@mtu.edu>
 *              Victor Eduardo <victoreduardm@gmail.com>
 */

using Gtk;
using Granite.Widgets;
using Gee;

public class BeatBox.ViewWrapper : Box {

	public LibraryManager lm { get; private set; }
	public LibraryWindow  lw { get; private set; }

	/* MAIN WIDGETS (VIEWS) */
	public ContentView   list_view      { get; private set; }
	public ContentView   album_view     { get; private set; }
	public MillerColumns column_browser { get; private set; }
	public WarningLabel  error_box      { get; private set; }
	public Welcome       welcome_screen { get; private set; }

	// Wrapper for the list view and miller columns
	private Paned list_view_hpaned; // for left mode
	private Paned list_view_vpaned; // for top mode
	private int   list_view_hpaned_position = -1;
	private int   list_view_vpaned_position = -1;

	private Notebook view_container; // Wraps all the internal views for super fast switching

	/**
	 * Type of visual representation of the media.
	 *
	 * IMPORTANT: Values _must_ match the index of the respective view in the view selector.
	 */
	public enum ViewType {
		ALBUM   = 0, // Matches index 0 of the view in lw.viewSelector
		LIST    = 1, // Matches index 1 of the view in lw.viewSelector
		ERROR   = 2, // For error boxes
		WELCOME = 3, // For welcome screens
		NONE    = 4  // Custom views
	}

	public ViewType current_view { get; private set; }

	/**
	 * This is by far the most important property of this object.
	 * It defines how child widgets behave and some other properties.
	 */
	public enum Hint {
		NONE,
		MUSIC,
		PODCAST,
		AUDIOBOOK,
		STATION,
		SIMILAR,
		QUEUE,
		HISTORY,
		PLAYLIST,
		SMART_PLAYLIST,
		CDROM,
		DEVICE_AUDIO,
		DEVICE_PODCAST,
		DEVICE_AUDIOBOOK,
		ALBUM_LIST;
	}

	public Hint hint { get; private set; }
	public int relative_id { get; private set; }


	public int index { get { return lw.mainViews.page_num(this); } }

	public bool is_current_wrapper {
		get {
			int _index = index;
			if (_index == -1)
				return false;
			bool is_current = (_index == lw.mainViews.get_current_page());
			//FIXME
			debug ("%s\t:: is_current_wrapper = %s", hint.to_string(), is_current.to_string());
			return is_current;
		}
	}


	/* UI PROPERTIES */

	public bool have_album_view {
		get {
			return album_view != null;
		}
	}

	public bool have_list_view {
		get {
			return list_view != null;
		}
	}

	// This property depends on $have_list_view. By design, we can't have miller columns
	// without the list view
	public bool have_column_browser {
		get {
			return (have_list_view && column_browser != null);
		}
	}

	public bool have_error_box {
		get {
			return error_box != null;
		}
	}

	public bool have_welcome_screen {
		get {
			return welcome_screen != null;
		}
	}

	public bool column_browser_enabled {
		get {
			if (have_column_browser)
				return column_browser.visible;
			else
				return false;
		}
		private set {
			if (have_column_browser) {
				column_browser.set_no_show_all (!value);
				if (value)
					column_browser.show_all ();
				else
					column_browser.hide ();
			}
		}
	}

	/**
	 * This boolean is extremely important. It defines whether we show the views or not,
	 * and also other widgets, like the error box or welcome screen.
	 */
	public bool have_media { get { return media_count > 0; } }



	/**
	 * MEDIA DATA
	 *
	 * These data structures hold information about the media shown in the views.
	 **/

	// ALL the media. Data source.
	public HashMap<int, int> medias { get; private set; }

	public int media_count { get { return (medias != null) ? medias.size : 0; } }

	// Media that's currently showed. Only used for search results
	public HashMap<int, int> showing_medias { get; private set; }

	// Holds the last search results (timeout). Helps to prevent useless search.
	private LinkedList<string> timeout_search;

	// Stops from searching same thing multiple times
	private string _last_search = "";

	public string get_search_string () {
		if (is_current_wrapper)
			return lw.searchField.get_text ();
		return _last_search;
	}

	// Stops from searching unnecesarilly when changing b/w 0 words and search get_hint().
	private bool showing_all { get { return showing_media_count == media_count; } }

	public int showing_media_count { get { return (showing_medias != null) ? showing_medias.size : 0; } }

	private bool setting_search = false;

	public bool needs_update;


	// for Hint.SIMILAR only
	public bool similarsFetched;
	private bool in_update;
	private bool initialized;


	public ViewWrapper (LibraryWindow lw, Collection<int> the_medias, string sort, Gtk.SortType dir,
	                     Hint the_hint, int id)
	{
		orientation = Orientation.VERTICAL;
		initialized = false;

		this.lm = lw.lm;
		this.lw = lw;

		this.relative_id = id;
		this.hint = the_hint;

		medias = new HashMap<int, int>();
		showing_medias = new HashMap<int, int>();
		timeout_search = new LinkedList<string>();

		foreach(int i in the_medias)
			medias.set(i, 1);

		// Setup view container
		view_container = new Notebook ();
		view_container.show_tabs = false;
		view_container.show_border = false;
		this.pack_start (view_container, true, true, 0);

		switch (the_hint) {
			case Hint.MUSIC:
				/* list, album and column views */
				album_view = new AlbumView (this, get_media_ids());
				list_view = new MusicTreeView (this, sort, dir, the_hint, id);
				column_browser = new MillerColumns (this);

				/* Add welcome screen */
				//FIXME: welcome_screen = new Welcome ("Test", "Fixme");

				break;
			case Hint.SIMILAR:
				/* list view only */
				list_view = new SimilarPane(this);

				error_box = new WarningLabel();
				error_box.show_icon = false;
				error_box.setWarning ("<span weight=\"bold\" size=\"larger\">" + _("Similar Media View") + "</span>\n\n" + _("In this view, BeatBox will automatically find medias similar to the one you are playing.") + "\n" + _("You can then start playing those medias, or save them for later."), null);
				break;
			case Hint.PODCAST:
				/* list view, album and column view */
				list_view = new PodcastListView (this);
				column_browser = new MillerColumns (this);
				album_view = new AlbumView (this, get_media_ids());

				/* Add welcome screen */
				//FIXME: welcome_screen = new Welcome ("Test", "Fixme");

				error_box = new WarningLabel();
				error_box.show_icon = false;
				error_box.setWarning ("<span weight=\"bold\" size=\"larger\">" + _("No Podcasts Found") + "</span>\n\n" + _("To add a podcast, visit a website such as Miro Guide to find RSS Feeds.") + "\n" + _("You can then copy and paste the feed into the \"Add Podcast\" window by right clicking on \"Podcasts\"."), null);

				break;
			case Hint.DEVICE_PODCAST:
				/* list view, album and column view */
				list_view = new PodcastListView (this);
				column_browser = new MillerColumns (this);
				album_view = new AlbumView (this, get_media_ids());

				error_box = new WarningLabel();
				error_box.show_icon = false;
				error_box.setWarning ("<span weight=\"bold\" size=\"larger\">" + _("No Podcasts Found") + "</span>\n\n" + _("To add a podcast, visit a website such as Miro Guide to find RSS Feeds.") + "\n" + _("You can then copy and paste the feed into the \"Add Podcast\" window by right clicking on \"Podcasts\"."), null);

				break;
			case Hint.STATION:
				/* list view and column view */
				list_view = new RadioListView(this, sort, dir, the_hint, id);
				column_browser = new MillerColumns (this);

				/* Add welcome screen */
				//welcome_screen = new Welcome ("Test", "Fixme");

				error_box = new WarningLabel();
				error_box.show_icon = false;
				error_box.setWarning ("<span weight=\"bold\" size=\"larger\">" + _("No Internet Radio Stations Found") + "</span>\n\n" + _("To add a station, visit a website such as SomaFM to find PLS or M3U files.") + "\n" + _("You can then import the file to add the station."), null);

				break;
			case Hint.AUDIOBOOK:
				/* list view, album and column view */
				list_view = new MusicTreeView(this, sort, dir, the_hint, id);
				column_browser = new MillerColumns (this);
				album_view = new AlbumView (this, get_media_ids());

				/* Add welcome screen */
				//welcome_screen = new Welcome ("Test", "Fixme");

				break;
			case Hint.DEVICE_AUDIOBOOK:
				/* list view, album and column view */
				list_view = new MusicTreeView(this, sort, dir, the_hint, id);
				column_browser = new MillerColumns (this);
				album_view = new AlbumView (this, get_media_ids());

				/* Add welcome screen */
				//welcome_screen = new Welcome ("Test", "Fixme");

				break;
			case Hint.CDROM:
				/* list view only. TODO: Add infobar */

				list_view = new MusicTreeView (this, sort, dir, the_hint, id);

				error_box = new WarningLabel();

				error_box.show_icon = false;
				error_box.setWarning ("<span weight=\"bold\" size=\"larger\">" + _("Audio CD Invalid") + "</span>\n\n" + _("BeatBox could not read the contents of this Audio CD."), null);

				break;
			default:
				/* list, album and column views */
				album_view = new AlbumView (this, get_media_ids());
				list_view = new MusicTreeView (this, sort, dir, the_hint, id);
				column_browser = new MillerColumns (this);

				break;
		}

		/* Now setup the view wrapper based on available widgets */

		if (have_error_box) {
			view_container.append_page (error_box);
			set_active_view (ViewType.ERROR);
		}

		if (have_welcome_screen) {
			view_container.append_page (welcome_screen);
			set_active_view (ViewType.WELCOME);
		}

		if (have_list_view) {
			list_view_hpaned = new Paned (Orientation.HORIZONTAL);
			list_view_vpaned = new Paned (Orientation.VERTICAL);
			
			// Fix theming
			list_view_hpaned.get_style_context().add_class (Gtk.STYLE_CLASS_HORIZONTAL);
			list_view_vpaned.get_style_context().add_class (Gtk.STYLE_CLASS_VERTICAL);

			list_view_hpaned.pack2(list_view_vpaned, true, false);

			// Add hpaned (the most-external wrapper) to the view container
			view_container.append_page (list_view_hpaned);

			//list_view_hpaned.set_position(lw.settings.get_column_browser_width());

			do_update (ViewType.LIST, null, false, true, false);

			//XXX:
			set_active_view (ViewType.LIST);
			do_update (current_view, null, false, true, false);

			// Now pack the list view
			list_view_vpaned.pack2(list_view, true, true);
		}

		if (have_column_browser) {
			list_view_hpaned.pack1(column_browser, true, true);

			// Read Paned position from settings
			list_view_hpaned_position = lw.settings.get_miller_columns_width ();
			list_view_vpaned_position = lw.settings.get_miller_columns_height ();

			list_view_hpaned.position = list_view_hpaned_position;
			list_view_vpaned.position = list_view_vpaned_position;

			set_column_browser_position (column_browser.position);

			column_browser.position_changed.connect (set_column_browser_position);

			//XXX:
			update_column_browser ();

			// For automatic position stuff
			this.size_allocate.connect ( () => {
				if (!lw.initializationFinished)
					return;
				
				if (column_browser.position == MillerColumns.Position.AUTOMATIC)
					set_column_browser_position (MillerColumns.Position.AUTOMATIC);
			});

			column_browser.size_allocate.connect ( () => {
				if (column_browser.actual_position == MillerColumns.Position.LEFT) {
					list_view_hpaned_position = list_view_hpaned.position;
				}
				else if (column_browser.actual_position == MillerColumns.Position.TOP) {
					list_view_vpaned_position = list_view_vpaned.position;
				}
			});

			lw.column_browser_toggle.toggled.connect ( () => {
				if (current_view == ViewType.LIST)
					column_browser_enabled = lw.column_browser_toggle.get_active();
			});

			// Connect data signals
			column_browser.changed.connect (column_browser_changed);
		}

		if (have_album_view) {
			view_container.append_page (album_view);

			//XXX:
			set_active_view (ViewType.ALBUM);
			do_update (current_view, null, false, true, false);
		}


		// XXX: hmmm, equivalent to updating above...
		needs_update = true;

		lw.viewSelector.mode_changed.connect (view_selector_changed);

		lm.medias_updated.connect (medias_updated);
		lm.medias_added.connect (medias_added);
		lm.medias_removed.connect (medias_removed);

		lw.searchField.changed.connect (search_field_changed);

		// We only save the settings when this view wrapper is being destroyed. This avoids unnecessary
		// disk access to write settings.
		destroy.connect (on_quit);

		//show_all ();

		initialized = true;
	}

	public ViewWrapper.with_view (Gtk.Widget view) {
		view_container.append_page (view);

		this.hint = Hint.NONE;
		set_active_view (ViewType.NONE);

		show_all ();

		update_library_window_widgets ();
		
		// FIXME: not needed. Update statusbar
		set_statusbar_info ();
	}


	private void on_quit () {
		// Save all the relevant stuff, such as list_view_hpaned and list_view_vpaned positions, etc.
		if (have_column_browser) {
			if (column_browser.actual_position == MillerColumns.Position.LEFT)
				lw.settings.set_miller_columns_width(list_view_hpaned.position);
			else if (column_browser.actual_position == MillerColumns.Position.TOP)
				lw.settings.set_miller_columns_height(list_view_vpaned.position);
		}
	}


	private void set_column_browser_position (MillerColumns.Position position) {
		MillerColumns.Position actual_position = position; //position that will be actually applied

		if (actual_position == MillerColumns.Position.AUTOMATIC) {
			// Decide what orientation to use based on the view area size

			int view_width = this.get_allocated_width ();
			const int MIN_TREEVIEW_WIDTH = 300;

			int visible_columns = 0;
			foreach (var column in column_browser.columns) {
				if (column.visible)
					++ visible_columns;
			}

			int required_width = column_browser.MIN_COLUMN_WIDTH * visible_columns;
			if (view_width - required_width < MIN_TREEVIEW_WIDTH)
				actual_position = MillerColumns.Position.TOP;
			else
				actual_position = MillerColumns.Position.LEFT;
		}

		column_browser.actual_position = actual_position;

		if (actual_position == MillerColumns.Position.LEFT) {
			if (list_view_hpaned.get_child1() == null && list_view_vpaned.get_child1() == column_browser) {
				list_view_vpaned.remove (column_browser);
				list_view_hpaned.pack1 (column_browser, true, true);
				
				list_view_hpaned.set_position (list_view_hpaned_position);
			}
		}
		else if (actual_position == MillerColumns.Position.TOP) {
			if (list_view_vpaned.get_child1() == null && list_view_hpaned.get_child1() == column_browser) {
				list_view_hpaned.remove (column_browser);
				list_view_vpaned.pack1 (column_browser, true, true);
				
				list_view_vpaned.set_position (list_view_vpaned_position);
			}
		}
	}


	/**
	 * Convenient visibility method
	 */
	private void set_active_view (ViewType type, out bool successful = null) {
		int view_index = -1;

		// Find position in notebook
		switch (type) {
			case ViewType.LIST:
				view_index = view_container.page_num (list_view_hpaned);
				break;
			case ViewType.ALBUM:
				view_index = view_container.page_num (album_view);
				break;
			case ViewType.ERROR:
				view_index = view_container.page_num (error_box);
				break;
			case ViewType.WELCOME:
				view_index = view_container.page_num (welcome_screen);
				break;
		}

		// i.e. we're not switching the view if it is not available
		if (view_index < 0) {
			warning ("Cannot set %s as the active view", type.to_string());
			successful = false;
			return;
		}

		// Set view as current
		current_view = type;

		view_container.set_current_page (view_index);

		// Update BeatBox's toolbar widgets
		update_library_window_widgets ();

		// FIXME: not needed, since do_update should do it. Update statusbar
		// set_statusbar_info ();

		successful = true;
	}

	/**
	 * This method ensures that the view switcher and search box are sensitive/insensitive when they have to.
	 * It also selects the proper view switcher item based on the current view.
	 */
	private void update_library_window_widgets () {
		if (!is_current_wrapper)
			return;

		debug ("Updating LibraryWindow widgets for %s", hint.to_string());

		// select the right view in the view selector if it's one of the three views
		if (lw.viewSelector.selected != (int)current_view && (int)current_view <= 2)
			lw.viewSelector.set_active ((int)current_view);

		// Restore this view wrapper's search string
		// NOTE: get_search_string() wouldn't work here since it'd return what the
		//       search field already contains (remember that we already set this as
		//       the current view).
		lw.searchField.set_text (_last_search);

		// Make the view switcher and search box insensitive if the current item
		// is either the error box or welcome screen
		if (current_view == ViewType.ERROR || current_view == ViewType.WELCOME) {
			lw.viewSelector.set_sensitive (false);
			lw.searchField.set_sensitive (false);
			lw.column_browser_toggle.set_active (false);
			lw.column_browser_toggle.set_sensitive (false);
		}
		else {
			// the view selector will only be sensitive if both views are available
			lw.viewSelector.set_sensitive (have_album_view && have_list_view);
			
			// Insensitive if there's no media to search
			lw.searchField.set_sensitive (have_media);
			
			// Sensitive only if the column browser is available and the current view type is list
			lw.column_browser_toggle.set_active (column_browser_enabled && current_view == ViewType.LIST);
			lw.column_browser_toggle.set_sensitive (have_column_browser && current_view == ViewType.LIST);
		}
	}

	/**
	 * @return a collection containing ALL the media
	 */
	public Collection<int> get_media_ids () {
		return medias.keys;
	}

	/*
	 * @return a collection with all the media that should be shown
	 */
	public Collection<int> get_showing_media_ids () {
		// FIXME: Dont search again if we already populated millers

		if (column_browser_enabled && initialized)
			return column_browser.media_results;

		// Perform search
		LinkedList<int> _search_results;

		lm.do_search (get_media_ids (), out _search_results, null, null, null, null,
		              hint, get_search_string());

		foreach (int i in _search_results)
			showing_medias.set (i, 1);

		return _search_results;
	}

	public virtual void view_selector_changed () {
		if (!lw.initializationFinished || (int)current_view == lw.viewSelector.selected || current_view == ViewType.ERROR || current_view == ViewType.WELCOME)
			return;

		var selected_view = (ViewType) lw.viewSelector.selected;

		// Only update data when switching between a filtered - non-filtered view
		/* XXX
		bool update_data = ((column_browser_enabled) ||
		                    (selected_view != ViewType.FILTER) ||
		                    (showing_media_count < 1)) &&
		                    is_current_wrapper;
		*/
		bool successful; // whether the view was available or not
		set_active_view (selected_view, out successful);

		//XXX
		//if (successful && update_data) {
			// Hide album view
			if (have_album_view)
				(album_view as AlbumView).album_list_view.hide ();

			// We need to do this since some views are filtered (i.e. column view) and others not
			do_update (current_view, null, false, false, false);
		//}
	}

	/**
	 * This handles updating all the shared stuff outside the view area.
	 *
	 * You should only call this method on the respective ViewWrapper whenever the sidebar's
	 * selected view changes.
	 *
	 * Note: The sidebar-item selection and other stuff is handled automatically by the LibraryWindow
	 *       by request of SideTreeView. See LibraryManager :: set_active_view() for more details. 
	 */
	public void set_as_current_view () {
		update_library_window_widgets ();
		
		// Update List View paned position to use the same position as the miller columns in other view wrappers
		if (have_column_browser) {
			if (column_browser.actual_position == MillerColumns.Position.LEFT && list_view_hpaned_position != -1)
				list_view_hpaned.set_position (list_view_hpaned_position);
			else if (column_browser.actual_position == MillerColumns.Position.TOP && list_view_vpaned_position != -1)
				list_view_vpaned.set_position (list_view_vpaned_position);
		}

		// Update statusbar
		set_statusbar_info ();
	}

	public void show_retrieving_similars() {
		if(hint != Hint.SIMILAR || !have_error_box || lm.media_info.media == null)
			return;

		error_box.show_icon = false;
		error_box.setWarning("<span weight=\"bold\" size=\"larger\">" + _("Loading similar songs") + "</span>\n\n" + _("BeatBox is loading songs similar to") + " <b>" + lm.media_info.media.title.replace("&", "&amp;") + "</b> by <b>" + lm.media_info.media.artist.replace("&", "&amp;") + "</b> " + _("..."), null);

		// Show the error box
		set_active_view (ViewType.ERROR);

		similarsFetched = false;
	}


	/**
	 * MEDIA-ADDED METHOD
	 *
	 * When a song is removed from a view, it has to be removed from the other views as well,
	 * since they're only visual representations of the same media.
	 */
	void medias_added(LinkedList<int> ids) {
		add_medias(ids);
	}

	/**
	 * Do search to find which ones should be added, removed from this particular view
	 * does not re-anaylyze smart playlist_views or playlist_views.
	 */
	public void medias_updated(LinkedList<int> ids) {
		if(in_update)
			return;

		in_update = true;

		if(is_current_wrapper) {
			// find which medias belong here
			LinkedList<int> shouldBe, shouldShow;

			LinkedList<int> to_search;

			if(hint == Hint.SMART_PLAYLIST)
				to_search = lm.smart_playlist_from_id(relative_id).analyze(lm, ids);
			else
				to_search = ids;

			lm.do_search (to_search, out shouldShow, null, null, null, null,
			              hint, get_search_string());

			lm.do_search (to_search, out shouldBe, null, null, null, null, hint);

			var to_add = new LinkedList<int>();
			var to_remove = new LinkedList<int>();
			var to_remove_show = new LinkedList<int>();

			// add elements that should be here
			foreach(int i in shouldBe) {
				medias.set(i, 1);
			}

			// add elements that should show
			foreach(int i in shouldShow) {
				if(showing_medias.get(i) == 0)
					to_add.add(i);

				showing_medias.set(i, 1);
			}

			// remove elements
			// FIXME: contains is slow
			foreach(int i in ids) {
				if(!shouldBe.contains(i)) {
					to_remove.add(i);
					medias.unset(i);
				}
			}

			foreach(int i in ids) {
				if(!shouldShow.contains(i)) {
					to_remove_show.add(i);
					showing_medias.unset(i);
				}
			}

			Idle.add( () => {
				if (have_list_view) {
					list_view.append_medias(to_add);
					list_view.remove_medias(to_remove_show);
				}

				if (have_album_view) {
					album_view.append_medias(to_add);
					album_view.remove_medias(to_remove_show);
				}

				update_column_browser ();

				set_statusbar_info();

				check_show_error_box();

				return false;
			});
		}
		else {
			needs_update = true;
		}

		in_update = false;
	}

	public void play_first_media () {
		if (have_list_view)
			list_view.set_as_current_list(1, true);
		else
			return;

		lm.playMedia (lm.mediaFromCurrentIndex(0), false);
		lm.player.play ();

		if(!lm.playing)
			lw.playClicked();
	}

	void medias_removed(LinkedList<int> ids) {
		if(in_update)
			return;

		in_update = true;
		var to_remove = new LinkedList<int>();
		foreach(int i in ids) {
			medias.unset(i);

			if(showing_medias.get(i) != 0)
				to_remove.add(i);

			showing_medias.unset(i);
		}

		if (have_list_view)
			list_view.remove_medias(to_remove);

		if (have_album_view)
			album_view.remove_medias(to_remove);

		update_column_browser ();

		check_show_error_box();

		needs_update = true;
		in_update = false;

		set_statusbar_info ();
	}

	public void clear() {
		medias = new HashMap<int, int> ();
		showing_medias = new HashMap<int, int>();

		// Now reset the views
		do_update (ViewType.LIST, null, false, false, false);
		do_update (ViewType.ALBUM, null, false, false, false);
		update_column_browser();
	}

	public void add_medias(LinkedList<int> new_medias) {
		if(in_update)
			return;

		in_update = true;

		if(hint == Hint.MUSIC || hint == Hint.PODCAST || hint == Hint.STATION) {
			// find which medias to add
			var to_add = new LinkedList<int>();
			foreach(int i in new_medias) {
				if(medias.get(i) == 0) {
					medias.set(i, 1);
					to_add.add(i);
				}
			}

			LinkedList<int> potential_showing;

			lm.do_search(to_add, out potential_showing, null, null, null, null,
			             hint, get_search_string());

			if (have_list_view)
				list_view.append_medias(potential_showing);

			if (have_album_view)
				album_view.append_medias(potential_showing);

			update_column_browser ();

			foreach(int i in potential_showing)
				showing_medias.set(i, 1);

			set_statusbar_info();
			check_show_error_box();
		}

		needs_update = true;
		in_update = false;

		set_statusbar_info ();
	}


	private void update_column_browser () {
		if (!have_column_browser)
			return;

		if(lw.initializationFinished)
			column_browser.populate (get_media_ids ());
	}



	/**
	 * Updates the displayed view and its content
	 *
	 * @param view the view to show/update
	 * @param medias If set_medias is true, then set this.medias = medias
	 * @param set_medias whether or not to set the medias
	 *
	 * Please note that some views, like the album and list views, are not filtered.
	 */
	public void do_update(ViewType type, Collection<int>? up_medias, bool set_medias, bool force, bool in_thread) {
		if (in_update)
			return;

		if ((type == ViewType.LIST && !have_list_view) || (type == ViewType.ALBUM && !have_album_view))
			return;

		in_update = true;

		if(set_medias && up_medias != null) {
			medias = new HashMap<int, int>();
			foreach(int i in up_medias)
				medias.set(i, 1);
		}

		var new_media = get_showing_media_ids ();

		if(!in_thread && check_show_error_box()) {
			in_update = false;
			return;
		}

		/* BEGIN special case for similar medias */
		if(!in_thread && have_list_view && list_view.get_hint() == Hint.SIMILAR && is_current_wrapper) {
			SimilarPane sp = (SimilarPane)(list_view);

			if(!similarsFetched) { // still fetching similar medias
				// Show the error box
				set_active_view (ViewType.ERROR);

				in_update = false;
				return;
			}
			else {
				if(media_count < 10) { // say we could not find similar medias
					if (have_error_box) {
						error_box.show_icon = true;
						error_box.setWarning("<span weight=\"bold\" size=\"larger\">" + _("No similar songs found") + "\n</span>\n" + _("BeatBox could not find songs similar to" + " <b>" + lm.media_info.media.title.replace("&", "&amp;") + "</b> by <b>" + lm.media_info.media.artist.replace("&", "&amp;") + "</b>.\n") + _("Make sure all song info is correct and you are connected to the Internet.\nSome songs may not have matches."), Justification.LEFT);
						// Show the error box
						set_active_view (ViewType.ERROR);
					}

					in_update = false;
					return;
				}
				else {
					sp._base = lm.media_info.media;
				}
			}
		}
		/* END special case */

		/* Even if it's a non-visual update, prepare the view's for the visual update */
		if(!is_current_wrapper || force || needs_update) {
			if (have_list_view) {
				list_view.set_show_next(new_media);
			}

			if (have_album_view)
				album_view.set_show_next(new_media);

			needs_update = false;
		}

		if(!in_thread && (is_current_wrapper || force)) {
			if(have_list_view && type == ViewType.LIST)
				list_view.populate_view();
			else if (have_album_view && type == ViewType.ALBUM)
				album_view.populate_view();
		}

		in_update = false;

		set_statusbar_info ();
	}


	bool check_show_error_box() {
		if (!have_error_box)
			return false;

		if((hint == Hint.CDROM || hint == Hint.PODCAST ||
		    hint == Hint.STATION) && is_current_wrapper)
		{
			int size_check = media_count;

			if(hint == Hint.PODCAST) {
				size_check = 0;
				foreach(int i in lm.podcast_ids()) {
					if(!lm.media_from_id(i).isTemporary)
						++size_check;
				}
			}

			if(hint == Hint.STATION) {
				size_check = 0;
				foreach(int i in lm.station_ids()) {
					if(lm.media_from_id(i) != null)
						++size_check;
				}
			}

			if(size_check == 0) {
				error_box.show_icon = (hint == Hint.CDROM);

				// Show error box
				set_active_view (ViewType.ERROR);

				return true;
			}
			// FIXME: these lines are not needed:
			else {
				if(have_list_view && current_view == ViewType.LIST) {
					// Show list view
					set_active_view (ViewType.LIST);
				}
				else {
					// Show album view
					set_active_view (ViewType.ALBUM);
				}
			}
		}

		return false;
	}

	public void set_statusbar_info() {
		if (!is_current_wrapper)
			return;

		if(showing_media_count < 1) {
			lw.set_statusbar_info (hint, 0, 0, 0);
			return;
		}

		uint count = 0;
		uint total_time = 0;
		uint total_mbs = 0;

		foreach(int id in get_showing_media_ids ()) {
			var media = lm.media_from_id (id);
			if (media != null) {
				count ++;
				total_time += media.length;
				total_mbs += media.file_size;
			}
		}

		lw.set_statusbar_info(hint, count, total_mbs, total_time);
	}

	public void column_browser_changed () {
		if(lw.initializationFinished) {
			// XXX
			//needs_update = true;
			//do_update(ViewType.FILTER, null, false, false, false);
		}
	}

	public virtual void search_field_changed() {
		if (!is_current_wrapper)
			return;
		
		/*
		// validate search string: no white space, etc.
		bool is_valid_string = false;
		int white_space = 0;

		string get_search_string() = get_search_string();
		int str_length = get_search_string().length;

		unichar c;
		for (int i = 0; get_search_string().get_next_char (ref i, out c);)
			if (c.isspace())
				++ white_space;

		if (white_space == str_length) {
			is_valid_string = true;
			debug ("detected white space");
			return;
		}
		*/

		if(!setting_search && lw.initializationFinished) {
			timeout_search.offer_head(_last_search.down());
			Timeout.add(200, () => {

				string to_search = timeout_search.poll_tail();
				if(to_search != _last_search || to_search == _last_search)
					return false;

				if(!setting_search && is_current_wrapper)
					_last_search = to_search;

				do_update(this.current_view, null, false, true, false);

				lm.settings.setSearchString(to_search);

				return false;
			});
		}
	}
}

