# Perlbug javascript routines
# (C) 2000 Richard Foley RFI perlbug@rfi.net
# $Id: JS.pm,v 1.1 2000/04/13 13:10:07 perlbug Exp perlbug $
#   
# Placeholder for javascript routines for Perlbug::Web
#  

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
:wq

