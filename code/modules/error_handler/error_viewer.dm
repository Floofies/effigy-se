// Error viewing datums, responsible for storing error info, notifying admins
// when errors occur, and showing them to admins on demand.

// There are 3 different types used here:
//
// - error_cache keeps track of all error sources, as well as all individually
//   logged errors. Only one instance of this datum should ever exist, and it's
//   right here:

#ifdef USE_CUSTOM_ERROR_HANDLER
GLOBAL_DATUM_INIT(error_cache, /datum/error_viewer/error_cache, new)
#else
// If debugging is disabled, there's nothing useful to log, so don't bother.
GLOBAL_DATUM(error_cache, /datum/error_viewer/error_cache)
#endif

// - error_source datums exist for each line (of code) that generates an error,
//   and keep track of all errors generated by that line.
//
// - error_entry datums exist for each logged error, and keep track of all
//   relevant info about that error.

// Common vars and procs are kept at the error_viewer level
/datum/error_viewer
	var/name = ""

/datum/error_viewer/proc/browse_to(client/user, html)
	var/datum/browser/browser = new(user.mob, "error_viewer", null, 600, 400)
	browser.set_content(html)
	browser.add_head_content({"
	<style>
	.runtime
	{
		background-color: #171717;
		border: solid 1px #202020;
		font-family: "Courier New";
		padding-left: 10px;
		color: #CCCCCC;
	}
	.runtime_line
	{
		margin-bottom: 10px;
		display: inline-block;
	}
	</style>
	"})
	browser.open()

/datum/error_viewer/proc/build_header(datum/error_viewer/back_to, linear)
	// Common starter HTML for show_to

	. = ""

	if (istype(back_to))
		. += back_to.make_link("<b>&lt;&lt;&lt;</b>", null, linear)

	. += "[make_link("Refresh")]<br><br>"

/datum/error_viewer/proc/show_to(user, datum/error_viewer/back_to, linear)
	// Specific to each child type
	return

/datum/error_viewer/proc/make_link(linktext, datum/error_viewer/back_to, linear)
	var/back_to_param = ""
	if (!linktext)
		linktext = name

	if (istype(back_to))
		back_to_param = ";viewruntime_backto=[REF(back_to)]"

	if (linear)
		back_to_param += ";viewruntime_linear=1"

	return "<a href='?_src_=holder;[HrefToken()];viewruntime=[REF(src)][back_to_param]'>[linktext]</a>"

/datum/error_viewer/error_cache
	var/list/errors = list()
	var/list/error_sources = list()
	var/list/errors_silenced = list()

/datum/error_viewer/error_cache/show_to(user, datum/error_viewer/back_to, linear)
	var/html = build_header()
	html += "<b>[GLOB.total_runtimes]</b> runtimes, <b>[GLOB.total_runtimes_skipped]</b> skipped<br><br>"
	if (!linear)
		html += "organized | [make_link("linear", null, 1)]<hr>"
		var/datum/error_viewer/error_source/error_source
		for (var/erroruid in error_sources)
			error_source = error_sources[erroruid]
			html += "[error_source.make_link(null, src)] x [error_source.errors.len]<br>" // EffigyEdit Change

	else
		html += "[make_link("organized", null)] | linear<hr>"
		for (var/datum/error_viewer/error_entry/error_entry in errors)
			html += "[error_entry.make_link(null, src, 1)]<br>"

	browse_to(user, html)

/datum/error_viewer/error_cache/proc/log_error(exception/e, list/desclines, skip_count)
	if (!istype(e))
		return // Abnormal exception, don't even bother

	var/erroruid = "[e.file][e.line]"
	var/datum/error_viewer/error_source/error_source = error_sources[erroruid]
	if (!error_source)
		error_source = new(e)
		error_sources[erroruid] = error_source

	var/datum/error_viewer/error_entry/error_entry = new(e, desclines, skip_count)
	error_entry.error_source = error_source
	errors += error_entry
	error_source.errors += error_entry
	if (skip_count)
		return // Skip notifying admins about skipped errors.

	// Show the error to admins with debug messages turned on, but only if one
	//  from the same source hasn't been shown too recently
	if (error_source.next_message_at <= world.time)
		var/const/viewtext = "\[view]" // Nesting these in other brackets went poorly
		//log_debug("Runtime in <b>[e.file]</b>, line <b>[e.line]</b>: <b>[html_encode(e.name)]</b> [error_entry.make_link(viewtext)]")
		var/err_msg_delay
		if(config?.loaded)
			err_msg_delay = CONFIG_GET(number/error_msg_delay)
		else
			var/datum/config_entry/CE = /datum/config_entry/number/error_msg_delay
			err_msg_delay = initial(CE.default)
		error_source.next_message_at = world.time + err_msg_delay

/datum/error_viewer/error_source
	var/list/errors = list()
	var/next_message_at = 0

/datum/error_viewer/error_source/New(exception/e)
	if (!istype(e))
		name = "\[[time_stamp()]] Uncaught exceptions"
		return

	name = "<b>\[[time_stamp()]]</b> Runtime in <b>[e.file]</b>, line <b>[e.line]</b>: <b>[html_encode(e.name)]</b>"

/datum/error_viewer/error_source/show_to(user, datum/error_viewer/back_to, linear)
	if (!istype(back_to))
		back_to = GLOB.error_cache

	var/html = build_header(back_to)
	for (var/datum/error_viewer/error_entry/error_entry in errors)
		html += "[error_entry.make_link(null, src)]<br>"

	browse_to(user, html)

/datum/error_viewer/error_entry
	var/datum/error_viewer/error_source/error_source
	var/exception/exc
	var/desc = ""
	var/usr_ref
	var/turf/usr_loc
	var/is_skip_count

/datum/error_viewer/error_entry/New(exception/e, list/desclines, skip_count)
	if (!istype(e))
		name = "<b>\[[time_stamp()]]</b> Uncaught exception: <b>[html_encode(e.name)]</b>"
		return

	if(skip_count)
		name = "\[[time_stamp()]] Skipped [skip_count] runtimes in [e.file],[e.line]."
		is_skip_count = TRUE
		return

	name = "<b>\[[time_stamp()]]</b> Runtime in <b>[e.file]</b>, line <b>[e.line]</b>: <b>[html_encode(e.name)]</b>"
	exc = e
	if (istype(desclines))
		for (var/line in desclines)
			// There's probably a better way to do this than non-breaking spaces...
			desc += "<span class='runtime_line'>[html_encode(line)]</span><br>"

	if (usr)
		usr_ref = "[REF(usr)]"
		usr_loc = get_turf(usr)

/datum/error_viewer/error_entry/show_to(user, datum/error_viewer/back_to, linear)
	if (!istype(back_to))
		back_to = error_source

	var/html = build_header(back_to, linear)
	html += "[name]<div class='runtime'>[desc]</div>"
	if (usr_ref)
		html += "<br><b>usr</b>: <a href='?_src_=vars;[HrefToken()];Vars=[usr_ref]'>VV</a>"
		html += " <a href='?_src_=holder;[HrefToken()];adminplayeropts=[usr_ref]'>PP</a>"
		html += " <a href='?_src_=holder;[HrefToken()];adminplayerobservefollow=[usr_ref]'>Follow</a>"
		if (istype(usr_loc))
			html += "<br><b>usr.loc</b>: <a href='?_src_=vars;[HrefToken()];Vars=[REF(usr_loc)]'>VV</a>"
			html += " <a href='?_src_=holder;[HrefToken()];adminplayerobservecoodjump=1;X=[usr_loc.x];Y=[usr_loc.y];Z=[usr_loc.z]'>JMP</a>"

	browse_to(user, html)

/datum/error_viewer/error_entry/make_link(linktext, datum/error_viewer/back_to, linear)
	return is_skip_count ? name : ..()
