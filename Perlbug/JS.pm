# Perlbug javascript routines
# (C) 2000 Richard Foley RFI perlbug@rfi.net
# $Id: JS.pm,v 1.13 2002/01/14 10:14:48 richardf Exp $
#   

=head1 NAME

Perlbug::JS - Object handler for Javascript methods

=cut

package Perlbug::JS;
use strict;
use vars qw(@ISA $VERSION);
$VERSION  = do { my @r = (q$Revision: 1.13 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
$| = 1; 

use CGI;

=head1 DESCRIPTION

Javascript wrapper for Perlbug modules usage

=head1 SYNOPSIS

	use Perlbug::JS;

	print Perlbug::JS->new()->menus;

=head1 METHODS

=over 4

=item new

Create new Perlbug::JS object.

	my $o_js = Perlbug::JS->new($isframed);

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 

	bless({
		'_is_framed'	=> shift || '',
	}, $class);
}

=item isframed

Return whether or not this window is framed

	my $i_framed = $o_js->isframed;

=cut

sub isframed {
	my $self = shift;

	return ($self->{'_is_framed'} =~ /\w+/) ? 1 : 0;
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
	# print "tgt($tgt) dom($dom) cgi($cgi)<hr>\n";

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
		. $self->isframed()
		. $self->onpageload()
	;

	return $func;
}

=item perlbug 

perlbug display suite

=cut

sub perlbug {
	my $self = shift;

	my $func = q|// function menus|
		. $self->go()
		. $self->isframed()
		. $self->onpageload()
		. $self->pick()
		. $self->sel()
	;

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
		. $self->goback()	
		. $self->go()
		. $self->isframed()
		. $self->onpageload()
		. $self->request()
		. $self->sel()
		. $self->show()	
		# . $self->static_load()	
		# . $self->parse()
		# . $self->frames()
	;
	return $func;
}

=item pick

pick an item from one of the checkboxes

=cut

sub pick {
	my $self = shift;

	my $func = q|
		function pick (item) {
			var nam = item.name;
			var pre = nam.substring(0, nam.indexOf("_")); // 19870502.007
			elems = document.forms[0].elements;
			// confirm("name(" + nam + ") first bit(" + pre + ")\n");
			for (var i = 0; i < elems.length; i++) {
				e = elems[i];  // 
				//confirm("name(" + e.name + ") first bit(" + e.value + ")\n");
				if (e.name.substr(e.name.length-2) == "id" && e.value == pre) {
				// if (e.name == "bugid" && e.value == pre) {
					e.checked = true; 
				} else {
					//confirm("Nope! name(" + e.name + ") value(" + e.value + ") ne pre(" + pre + ")\n");
				}
			}
		}
	|;

	return $func;
}

=item goback 

goback(n) perlbug display

=cut

sub goback {
	my $self = shift;

	my $func = q|
		function goback () {
			if (isframed()) {
				parent.perlbug.history.back();
			} else {
				top.history.back;
			}
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
				if (e.name.substr(e.name.length-2) == "id") {
					e.checked = tf;
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

	my $pane = $self->isframed ? 'parent.perlbug.document' : 'top.document';

	my $func = qq#
		function admin (arg) {
			var f = $pane.forms[0];
			var url = '';

			for (var i = 0; i < f.elements.length; i++) {
				var e = f.elements[i];
				if (e.type == "select-one" || e.type == "select-multiple") {
					for (var s = 0; s < e.options.length; s++) {
						if (e.options[s].selected) {
							url += "&" + e.name + "=" + escape(e.options[s].value);
						}
					}
				} else {
					url += "&" + e.name + "=" + escape(e.value);
				}
			}
			if (url.substring(0, 1) == "&") { 
				url = url.substring(1); // trim it
			}

			var path = $pane.location.pathname;
			var p = path.split("/admin");	
			var noadmin = p.join("");
			if (arg == 1) {
				// url = "/admin" + noadmin + "?" + url;
				url = "/perlbug/admin/perlbug.cgi" + "?" + url; 	// rfi
			} else {
				url = noadmin + "?" + url;
			}
			if (confirm("confirm url: " + url)) {
				// $pane.location.pathname = url;
				$pane.location.replace(url);
			}
			return false;
		}
	#;

	return $func;
}

=item onpageload

Arrange the command buttons

=cut

sub onpageload {
	my $self = shift;

	my $func = q|  
		function onPageLoad (req, command) {
			if (this.name == "perlbug") {
				c = top.location;
				p = top.document.forms[0];
				if (isframed()) {
					c = top.commands.location;
					p = top.perlbug.document.forms[0];
				}
				c.search = "?req=commands&commands=" + command;
				if (p.req.value == "") {
					p.req.value = req;
				}
				return true;
			}
		}
	|;

	return $func;
}

=item request

Call top.(perlbug?).document[0].submit() 

=cut

sub request {
	my $self = shift;

	my $func = q|  
		function request (item) {
			if (isframed()) {
				var f = parent.perlbug.document.forms[0];
				f.req.value = item.value;
				f.submit();
			} else {
				var f = parent.document.forms[0];
				f.req.value = item.value;
				f.submit();
			}
			return false;
		}
	|;

	return $func;
}

=item go

Go directly to given search query

=cut

sub go {
	my $self = shift;

	my $func = q#  
		function go (target) { // bug_id&bug_id="xxx" || search || home
			if (isframed()) {
				top.perlbug.location.search = "?req=" + target;
				return false;
			} else {
				top.location.search = "?req=" + target;
				return true;
			}
		}
	#;

	return $func;
}

=item show

...

=cut

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

=item isframed

Return 1 or 0 dependent on whether we're in a framed window or not

=cut

{ $^W=0; eval ' 
sub isframed {
	my $self = shift;

	my $func = q|  
		function isframed () {
			p = document.location.pathname;     // .../perlbug/admin/_perlbug.cgi
			var scor = p.substr(p.length-12, 1); // not for bugcgi
			// confirm("path(" + p + ") -> scor(" + scor + ")");
			if (scor == "_") {
				return 0;
			} else {
				return 1;
			}
		}    
	|;

	return $func;
}
'; }

=item frames

...

=cut

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

=item parse

...

=cut

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

__END__

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

