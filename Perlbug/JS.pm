# Perlbug javascript routines
# (C) 2000 Richard Foley RFI perlbug@rfi.net
# $Id: JS.pm,v 1.10 2001/09/18 13:37:49 richardf Exp $
#   

=head1 NAME

Perlbug::JS - Object handler for Javascript methods

=cut

package Perlbug::JS;
use strict;
use vars qw(@ISA $VERSION);
$VERSION  = do { my @r = (q$Revision: 1.10 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
$| = 1; 

use CGI;


=head1 DESCRIPTION

Javascript wrapper for Perlbug modules usage

=cut


=head1 SYNOPSIS

	use Perlbug::JS;

	print Perlbug::JS->new()->menus;

=cut


=head1 METHODS

=over 4

=item new

Create new Perlbug::JS object.

	my $o_js = Perlbug::JS->new;

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 

	bless({}, $class);
}


=item control

Return a popup, this will display the data and submit the form on the given frame/target/item.

	my $control = $o_js->control('menus');

=cut

sub control {
	my $self = shift;
	my $tgt  = shift;
	my $dom  = shift;
	my $cgi  = shift;
	print "tgt($tgt) dom($dom) cgi($cgi)<hr>\n";

	my %commands = (
		'frames' => 'frames',
		'parse'	=> 'parse',
		'title'	=> ucfirst($tgt),
	);

	my $control = "&nbsp; ".CGI::popup_menu(
		-'name'		=> $tgt,
		-'default'	=> 'title',
		-'values'	=> [keys %commands],
		-'labels'	=> \%commands,
		-'onChange'    => "show(parent.$tgt.document.forms[0],this.options[this.options.selectedIndex].value)", # commands|perlbug|menu?
		# -'onChange'    => "show(document.$tgt)", # commands|perlbug|menu?
		-'onBlur' => "top.status='$tgt'; return true;",
		-'onMouseOut'  => "window.status=''; return true;",
		# -'onChange' => "show(document.commands.test)",
		# -'onChange' => "show(document.perlbug)",
	);

	return $control;
}


=item menus

menu suite

=cut

sub menus {
	my $self = shift;

	my $func = q|// function menus|
		. $self->go()
	;

	return $func;
}


=item perlbug 

perlbug display suite

=cut

sub perlbug {
	my $self = shift;
	my $func = q|
		function pick (item) {
			var nam = item.name;
			var pre = nam.substring(0, nam.indexOf("_"));
			elems = document.forms[0].elements;
			for (var i = 0; i < elems.length; i++) {
				e = elems[i];
				if (e.name == "bugids" && e.value == pre) {
					/* if (confirm(
						"SELECT ? e(" + e + ")\n" + 
						"\tname(" + e.name + ")\n" +
						"\tval(" + e.value + ")\n" +
						"\tpre(" + pre + ")\n" +
						"\tchecked(" + e.checked + ")?\n"
					)) {
					*/
						e.checked = true; 
					//	confirm("SELECTED(" + e.checked + ")?\n")
				}
			}
		}
	|;
	return $func;
}


=item back 

back(n) perlbug display

=cut

sub back {
	my $self = shift;
	my $func = q|
		function back (n) {
			if (n == 0) { n = 1; };
			//parent.perlbug.history.go(-1);
			parent.perlbug.history.back();
			return false;
		}
	|;
	return $func;
}


=item sel 

sel(1) = select all items, or sel(0) = deselect

=cut

sub sel {
	my $self = shift;
	my $func = q|
		function sel (tf) {
			elems = parent.perlbug.document.forms[0].elements;
			for (var i = 0; i < elems.length; i++) {
				e = elems[i];
				if (e.name == "bugids") {
					e.checked = tf;
					// if (tf == "0") {
					//   p.items.value = 0;
					// } else {
					//   p.items.value++;
					// }
				}
			}
			return false;
		}
	|;
	return $func;
}


=item admin

Switch admin view on(1) or off(0)

=cut

sub admin {
	my $self = shift;
	my $dom  = shift;
	my $cgi  = shift;
	my $func = qq|
		function admin (arg) {
			var path = parent.perlbug.document.location.pathname;
			var p = path.split("/admin");	
			var noadmin = p.join("");
			var newloc = noadmin;
			if (arg == 1) {
				newloc = "/admin" + noadmin;
				//newloc = "/perlbug/admin/perlbug.cgi"; // rfi 
			}
			// confirm ("arg(" + arg + ") path(" + path + ") => newloc(" + newloc + ")");
			parent.perlbug.document.location.pathname = newloc;
			return false;
		}
	|;
	return $func;
}


=item commands 

commands suite

=cut

sub commands {
	my $self = shift;
	my $dom  = shift;
	my $cgi  = shift;
	my $func .= q|// commands functions|
		. $self->admin($dom, $cgi)	
		. $self->back()	
		. $self->newcoms()
		. $self->request()
		. $self->sel()
		. $self->show()	
		# . $self->parse()
		# . $self->frames()
	;
	return $func;
}

sub request {
	my $self = shift;
	my $func = q|  
		function request (item) {
			parent.perlbug.document.forms[0].req.value=item.value; 
			//var rem =  parent.perlbug.document.forms[0].req.value;
			//var val = item.value;

			//if (val == "update" or val == "nocc" or val == "delete") {
			//if (!(p.items.value >= 1)) {
			//	alert("Please select something for the " + val + " command!");
			//}

			//if (confirm(
			//		"Are you sure: " + item.name + "(" + val + ")=" + rem + "?\n"
			//)) {
				//r = parent.ranges.location.search;
				//r = "?req=ranges&commands=go";
				parent.perlbug.document.forms[0].submit(); // op
			//}
			return false;
		}
	|;
	return $func;
}

sub go {
	my $self = shift;
	my $func = q#  
		function go (target) {
			p = top.perlbug.location;
			p.search = "?req=" + target;
			c = top.commands.location;
			if (target == "group" || target == "administrators") {
				c.search = "?req=commands&commands=write";
			} else {
				c.search = "?req=commands&commands=read";
			}
			return false;
		}
	#;
	return $func;
}

sub newcoms {
	my $self = shift;
	my $func = q#  
		function newcoms (target) {
			c = top.commands.location.search;
			//r = top.ranges.location.search;
			if (target == "write" || target == "query") {
				if (target == "write") {
					//r = "?req=ranges&commands=newcom";
					c = "?req=commands&commands=write";
				} else {
					//r = "?req=ranges&commands=NEWcom";
					c = "?req=commands&commands=query";
				}	
			} else {
				//r = "?req=ranges&commands=newCOM";
				c = "?req=commands&commands=read";
			}
			return false;
		}
	#;
	return $func;
}

sub show {
	my $self = shift;
	my $func = q|  
		function show (pane, call) { /* form, call */
			if (confirm(
				" pane(" + pane.name + ") call(" + call + ") ?" + pane + "\n" + top
			)) {
				var data = "";
				if (call == "parse") {
					data = parse(pane);
				}
				if (call == "frames") {
					data = frames(pane);
				}
				if (call == "title") {
					data = pane.name;
				}
				w = window.open("", "show", "status,scrollbars", "");
				w.document.write("<pre>" + data + "</pre>");
				//w.close();
			}
			return 1;
		}
	|;
	return $func;
}

sub frames {
	my $self = shift;
	my $func = q|  
		function frames () {
			var out = "Frames: \n";
			var a   = 0;
			while (a < top.frames.length) {
				elem = top.frames[a];
				out += " name(" + elem.name + "), \t";
				out += " value(" + elem.document + ")\n";
				a++;
			}
			return(out);
		}    
	|;
	return $func;
}


sub parse {
	my $self = shift;
	my $func = q|
		function parse (pane) {
			//alert("args: (" + arguments.length + "): " + arguments);
			var out = "Parse: \n";
			var a   = 0;
			while (a < arguments.length) {
				if (a >= 5) {
					alert("Breaking debug loop at " + a);
					break;
				}
				var arg = arguments[a];
				out += arg + "\n";
				for (var i in arg) {
					out += "\t" + i + "=" + arg[i] + "\n";
				}
				a++;
			}
			return(out);
		}         
	|;
	return $func;
}

1;

=pod

=back

=cut

__END__


=pod

<form name=ws_pub_entries_list_footer>
<table width=100% height=100% bgcolor=8FBC8F>
<tr><td align=center valign=top>
<input type=button value="  Start  " onClick="check_form()">
</td>
<td align=center valign=top>
<select size=1 name=func >
  <option value="NO" selected>Functions:
  <option value="PUB_DM_ENTRIES_INSERTWS" >Insert single WS Entry
  <option value="PUB_DM_ENTRIES_DELSELWS" >Delete selected Entries
  <option value="PUB_DM_ENTRIES_SET" >Generate DM Set
  <option value="PUB_DM_ENTRIES_EXPORT" >Export to SGML List File
</select>
</td>
<td align=center valign=top>
<input type=button value="  UnSel  " onClick="parent.f2.nosel_button()">
</td>
<td align=center valign=top>
<input type=button value="   Sel   " onClick="parent.f2.sel_button()">
</td>
<td align=center valign=top>
<input type=button value="  Help   " onClick="help_system()">
</td>
<td align=center valign=top>
<input type=button value="  Back   " onClick="parent.f2.back_frames(0)">
</td>
</tr>
</table>
<input type=hidden name=set_name value="">
<input type=hidden name=setdel value="NO">
</form>


<!--
function nosel_button( ) {
  var i = 0;
  for (i=0; i < document.PUB_DM_ENTRIES_2_SEARCH2.length; ++i) {
    if ( document.PUB_DM_ENTRIES_2_SEARCH2.elements[i].type == "checkbox" ) {
      document.PUB_DM_ENTRIES_2_SEARCH2.elements[i].checked = false;
      }
    }
  }
function sel_button( ) {
  var i = 0;
  for (i=0; i < document.PUB_DM_ENTRIES_2_SEARCH2.length; ++i) {
    if ( document.PUB_DM_ENTRIES_2_SEARCH2.elements[i].type == "checkbox" ) {
      document.PUB_DM_ENTRIES_2_SEARCH2.elements[i].checked = true;
      }
    } 
  }
// -->
function flag_on (flag) {
    flag.value = 1;
    return true;
}
function flag_off (flag) {
    flag.value = 0;
    return true;
}

function cur_set (e) {
    var out = parse_objects(e);
    alert("event: " + e + ": " + out);
    if (this.form.general_applic.focus == 1) {
        alert("hi");
    }
    if (1 == 1) {
        alert("setting page x: " + e.pageX + ", y: " + e.pageY);
    } else {
        alert("not setting xy");
    }
    return true;
}

function cb_on () {
    //alert("args: (" + arguments.length + "): " + arguments);
    var a   = 0;
    while (a < arguments[0].length) {
        if (a >= 11) {
            alert("Breaking loop at " + a);
            break;
        }
        var arg = arguments[0][a];
        arg.checked = 1;
        a++;
    }
    return true;
}

function cb_off () {
    //alert("args: (" + arguments.length + "): " + arguments);
    var a   = 0;
    while (a < arguments[0].length) {
        if (a >= 11) {
            alert("Breaking loop at " + a);
            break;
        }
        var arg = arguments[0][a];
        arg.checked = 0;
        a++;
    }
    return true;
}

/*
 * update_item_val (object_with_value, value_to_insert, debug, place_holding_character)
 * -------------------------
 */
function update_item_val (target, param, debug, character) {
        if (debug == 1) {
            var out = parse_objects(target, param, character);
            alert("update_item_val(args):\n" + out);
        }
        var hint   = "";
        var orig   = target.value;
        var output = "";
        var split  = orig.indexOf(character);
        if (split >= 0) {
            var pre    = orig.substr(0, split);
            var post   = orig.substr(split + 1, orig.length -1);
            /* alert("pre: '" + pre + "'\n\npost: '" + post + "'"); */
            hint = "using '" + character + "' as the replacement character\n\n";
            output = pre + param + post;
        } else {
            output = target.value + param;
        }
        if (confirm("original: '" + orig + "\n\n" + hint + "outputs: '" + output + "'") ) {
            target.value = output;
            target.focus();
        }
}

/*
 * uga
 * -------------------------
 */
function update_general_applic (given, form, character) {
        var target = form.general_applic;
        var orig   = form.general_applic.value;
        var param  = given.options[given.options.selectedIndex].value;
        if (param == "z") {
            param  = location.href;
        }
        var hint   = "";
        var output = "";
        var split  = orig.indexOf("~");
        if (split >= 0) {
            var pre    = orig.substr(0, split);
            var post   = orig.substr(split + 1, orig.length -1);
            /* alert("pre: '" + pre + "'\n\npost: '" + post + "'"); */
            hint = "using '~' as the replacement character\n\n";
            output = pre + param + post;
        } else {
            output = target.value + param;
        }
        if (confirm("original: '" + orig + "\n\n" + hint + "outputs: '" + output + "'") ) {
            target.value = output;
            target.focus();
        }
}

/*
 * object construct, display
 * -------------------------
 */
function thing (arg1, arg2, arg3, arg4) {
    this.name   = arg1;
    this.genapp = arg2;
    this.modify = arg3;
    this.obj    = arg4;
}

function demo_obj (arg1, arg2, arg3, arg4) {
    var o = new thing(arg1, arg2, arg3, arg4);
    var out = "";
    for (var i in o) {
        out += "\t" + i + "\t= " + o[i] + "\n";
    }
    alert("new Obj (blob)\n" + out);
}


=cut

