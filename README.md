# public-scripts

Public scripts for assorted web maintenance tasks used in my server.

# This is a mirrored repository

If you're browsing this repository from [Codeberg](https://codeberg.org/csolisr/public-scripts) or [GitHub](https://github.com/csolisr/public-scripts), you should know that the main home for these files is on [my personal server over Forgejo](https://code.azkware.net/csolisr/public-scripts).

# Description

As you can see, the vast majority of my scripts are used to handle my [Friendica](https://friendi.ca) server, especially where the default PHP would take too long or not cover my usage case.

* copy.sh: The "build script" specific to my usage case. It requires `shfmt` and `shellcheck` installed to clean up the scripts. Also, since my repository is on `Document/Repositories/public-scripts` and my actual scripts are on `Document/Scripts`, it copies the files there as well, with the placeholder URLs changed for my server's. Finally, it copies the relevant scripts to my cron folder if they exist, with output off (uncommenting the `#&> /dev/null`). You can, of course, parameterize your own settings using the required files `settings.csv` and `credentials.csv` - samples of each are provided in this repository.
* friendica-clean-database.sh: Basically, it does the same things that the included ExpirePosts, but with the option to be more aggressive than the defaults (deleting items that are 7 days old instead of 60, for example).
* friendica-compress-storage.sh: It searches for any image files in the storage folder, and compresses them accordingly. Requires `gifsicle`, `oxipng`, `jpegoptim`, and `cwebp` installed.
* friendica-delete-old-users.sh: Complimentary to the included RemoveUnusedContacts, it deletes the posts from any users that have not posted anything in the last year (by default), and aren't in any user's contact list.
* friendica-delete-old-users-full.sh: Same as above, but it fully deletes the users from the database instead of just deleting their posts.
* friendica-find-missing-servers.sh: Complimentary to the included RemoveUnusedContacts, it finds any offline servers and deletes any users from them, that aren't in any user's contact list.
* friendica-fix-avatar-permissions.sh: Used to properly transfer avatars from `storage` to `avatar` with the correct permissions, and also compresses the files accordingly. Requires `gifsicle`, `oxipng`, `jpegoptim`, and `cwebp` installed.
* friendica-delete-non-followed-featured-posts.sh: If you accidentally configured Friendica to fetch featured posts from all interactors instead of known followers only, this script removes the related workers from the queue while leaving the known followers in place.
* friendica-remove-invalid-photos.sh: Used to fix issues with blank images due to a botched transfer from `storage` to `avatar`, for example. It finds any broken items in the database and removes them for regeneration later. Requires `curl`.
* friendica-remove-old-photos-parallel.sh: Finds any files in `avatar` that are no longer associated to any contact and deletes them.
* friendica-workerqueue.sh: Just a SQL query that shows the worker queue sorted by type of job.
* friendica-find-largest-accounts.sh: Finds which are the contacts that have the most posts assigned to them.
* friendica-delete-specific-contact.sh: Uses the same code as the previous scripts to delete all data from a specific user, particularly useful for unfollowed contacts with too many posts.
* media-optimize-local.sh: For a given folder, it finds any image files within and compresses them. Requires `gifsicle`, `oxipng`, `jpegoptim`, and `cwebp` installed.
* youtube-download-channel.sh: A wrapper to ease downloading metadata from subscriptions or channels, in order to export it as a CSV, and as a playlist DB file compatible with FreeTube. Requires `yt-dlp`, `jq`, `zstd`, and optionally a cookie to download your subscriptions.
* friendica-local-backfill-lemmy.sh: Used to backfill the Friendica server with data from all the Lemmy / Piefed servers that are followed by the users of the server. It requires generating an application key with OAuth.
* trending-hashtags.sh: Used to backfill the Friendica server with trending content from the most popular servers from the Fediverse. It requires generating an application key with OAuth.
* mariadb-delete-unallocated-items.sh: Allows deleting dangling items from tables with complex dependencies on MariaDB. Used here mainly to remove references to `item-uri` on Friendica. (Ensure you activate `enable-maximum-item` if you use this on a running Friendica instance)

# License

As most of these files are based on content from Friendica (especially its queries), the repository is also under the [Affero General Public License](https://www.gnu.org/licenses/agpl-3.0.en.html).
