/*-
 * Copyright (c) 2011       Scott Ringwelski <sgringwe@mtu.edu>
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
 */

using Gtk;
using Gee;

public class BeatBox.SimilarSongsView : TreeView {
	private BeatBox.LibraryManager _lm;
	private BeatBox.LibraryWindow _lw;
	private new ListStore model;
	private LinkedList<Song> songs;
	
	private LinkedList<string> urlsToOpen;//queue for opening urls
	
	public SimilarSongsView(BeatBox.LibraryManager lm, BeatBox.LibraryWindow lw) {
		_lm = lm;
		_lw = lw;
		songs = new LinkedList<Song>();
		urlsToOpen = new LinkedList<string>();
		
		/* id is always first and is stored as an int. Then the rest are (1)
		 * strings (for simplicity), and include:
		 * #, track, title, artist, album, genre, comment, year, rating, (9)
		 * bitrate, play count, last played, date added, file name, (5)
		 * bpm, length, file size, (3) */
		model = new ListStore(2, typeof(BeatBox.Song), typeof(string), -1);
		
		TreeViewColumn col = new TreeViewColumn();
		col.title = "song";
		col.visible = false;
		insert_column(col, 0);
		
		insert_column_with_attributes(-1, "Similar Songs", new CellRendererText(), "markup", 1, null);
		get_column(1).sizing = Gtk.TreeViewColumnSizing.FIXED;
		get_column(1).set_alignment((float)0.5);
		
		set_model(model);
		//set_grid_lines(TreeViewGridLines.HORIZONTAL);
		
		row_activated.connect(viewDoubleClick);
	}
	
	public void populateView(Collection<Song> nSongs) {
		songs.clear();
		model.clear();
		
		int count = 0;
		foreach(Song s in nSongs) {
			songs.add(s);
			
			TreeIter iter;
			model.append(out iter);
			
			var title_fixed = s.title.replace("&", "&amp;");
			var artist_fixed = s.artist.replace("&", "&amp;");
			
			model.set(iter, 0, s, 1, "<b>" + title_fixed + "</b>" + " \n" + artist_fixed );
			++count;
			
			if(count >= 16)
				return;
		}
	}
	
	public virtual void viewDoubleClick(TreePath path, TreeViewColumn column) {
		try {
			Thread.create<void*>(take_action, false);
		}
		catch(GLib.ThreadError err) {
			stdout.printf("ERROR: Could not create thread to have fun: %s \n", err.message);
		}
	}
	
	public void* take_action () {
		TreeIter iter;
		TreeModel mo;
		Song s;
		
		get_selection().get_selected(out mo, out iter);
		mo.get(iter, 0, out s);
		
		if(BeatBox.Beatbox.enableStore) {
			Store.store store = new Store.store();
			
			for(int i = 0; i < 3; ++i) {
				stdout.printf("testing page %d\n",i);
				foreach(var track in store.searchTracks(s.title, i)) {
					if(track.title.down() == s.title.down() && track.artist.name.down() == s.artist.down()) {
						_lm.playTrackPreview(track, track.getPreviewLink());
						
						return null;
					}
				}
			}
		}
		
		// fall back to just opening the last fm page
		if(s != null && s.lastfm_url != null && s.lastfm_url != "") {
			try {
				GLib.AppInfo.launch_default_for_uri (s.lastfm_url, null);
			}
			catch(Error err) {
				stdout.printf("Couldn't open the similar song's last fm page: %s\n", err.message);
			}
		}
		
		return null;
	}
}
