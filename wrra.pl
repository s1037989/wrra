use Mojolicious::Lite;  
use Mojo::JSON;
use File::Basename;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Schema;
use Data::Walk;
use Switch;

use Data::Dumper;

my $basename = basename $0, '.pl';
plugin Config => {
	default => {
		year => $ENV{WRRA_YEAR} || 2012,
		db => {
			db => $basename,
			host => 'localhost',
			user => $basename,
			pass => $basename,
		},
	}
};
app->config(hypnotoad => {pid_file=>"$Bin/../$basename", listen=>[split ',', $ENV{MOJO_LISTEN}], proxy=>$ENV{MOJO_REVERSE_PROXY}});

plugin 'write_excel';
plugin 'IsXHR'; # Needed because jqGrid send multiple content-types.  https://github.com/kraih/mojo/issues/227
                # However, this is bad because now all xhr's are considered json.  What if xml was requested?

helper db => sub { Schema->connect({dsn=>"DBI:mysql:database=".app->config->{db}->{db}.";host=".app->config->{db}->{host},user=>app->config->{db}->{user},password=>app->config->{db}->{pass},year=>app->config->{year}}) };
helper json => sub {
	my $self = shift;
	unless ( $self->{__JSON} ) {
		my $json = new Mojo::JSON;
		$self->{__JSON} = $json->decode($self->req->body);
#warn Dumper($self->{__JSON});
	}
	return $self->{__JSON}||{};
};
helper search => sub {
	my $self = shift;
	my ($field, $oper, $string);
	if ( not defined $_[0] ) {
		($field, $oper, $string) = map { $self->json->{$_}||'' } qw/searchField searchOper searchString/;
	} elsif ( ref $_[0] eq 'ARRAY' ) {
		($field, $oper, $string) = map { $self->json->{$_}||'' } @_;
	} elsif ( !ref $_[0] ) {
		($field, $oper, $string) = @_;
	}
	my $sopt = {
		eq => {'=' => $string},
		ne => {'!=' => $string},
		lt => {'<' => $string},
		le => {'<=' => $string},
		gt => {'>' => $string},
		ge => {'>=' => $string},
		bw => {'like' => $string.'%'},
		bn => {'not like' => $string.'%'},
#		in => {'<' => $string},
#		ni => {'<' => $string},
		ew => {'like' => '%'.$string},
		en => {'not like' => '%'.$string},
		cn => {'like' => '%'.$string.'%'},
		nc => {'not like' => '%'.$string.'%'},
	};
	my @search = $field && $oper ? ("me.$field" => $sopt->{$oper}) : ();
#warn Dumper(\@search);
	return @search;
};
helper order_by => sub {
	my $self = shift;
warn "ROUTE: ", $self->json->{grid}, "\n";
	switch ( $self->json->{grid} ) {
		case 'rotarians' {
			switch ( $self->json->{sidx} ) {
				case 'name' {
					return order_by => {'-'.($self->json->{sord}||'asc')=>['me.lastname','me.firstname']};
				}
				else {
					return order_by => $self->json->{sidx} ? {'-'.($self->json->{sord}||'asc')=>'me.'.$self->json->{sidx}} : undef;
				}
			}
		}
		case 'donors' {
			switch ( $self->json->{sidx} ) {
				case 'contact' {
					return order_by => {'-'.($self->json->{sord}||'asc')=>'me.contact1'};
				}
				case 'rotarian' {
					return order_by => {'-'.($self->json->{sord}||'asc')=>['rotarian.lastname', 'rotarian.firstname']};
				}
				else {
					return order_by => $self->json->{sidx} ? {'-'.($self->json->{sord}||'asc')=>'me.'.$self->json->{sidx}} : undef;
				}
			}
		}
		else {
			return order_by => $self->json->{sidx} ? {'-'.($self->json->{sord}||'asc')=>'me.'.$self->json->{sidx}} : undef;
		}
	}
};
# DEBUG!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
helper rows => sub { my $self = shift; return (page => $self->json->{page}||1, rows => $self->json->{rows}||10) };
#helper bind => sub {
#	my $self = shift;
#	return bind => [map { $self->session->{$_}||$self->stash->{$_}||$self->config->{$_}||undef } @_];
#};

##############################
# IMPORTANT
# use ->hashref_array when you want to prefetch a bunch of data and return a tree.  NO RESULTCLASS OBJECT HANDLING!
#    use for custom non-grid handling
# use ->all when you want to process methods via TO_JSON.  DO NOT CHAIN RELATIONSHIPS!
#    use for grid handling.  Rather than chaining relationships, specify each method in TO_JSON.  Think 2D vs 3D.
#    Then apply a result_class "filter" to select the TO_JSON you want
##############################

get '/' => 'index';
get '/bookmarks';

under '/api';
group {
	get '/buildselect/:for' => (is_xhr => 1) => sub { # Authen Authz('admins')
		my $self = shift;

		my $select = {};
		switch ( $self->param('for') ) {
			case 'rotarians' {
				$self->stash(select => [$self->db->resultset('Rotarian')->search({}, {select=>['rotarian_id',\'concat_ws(", ",lastname,firstname)'], as => [qw/rotarian_id name/], order_by=>'lastname'})->warn_json->hashref_array]);
			}
#			case 'bellitems' {
#				my $bidder_id = $self->param('bidder_id');
#				my ($sql, @bind) = sql_interp 'select * from bs_bellitem_vw where', {bidder_id=>$bidder_id};
#				$select = $self->dbh->selectall_arrayref($sql, {}, @bind);
#				#SELECT bellitem_id,bellitem name FROM bellitems ORDER BY bellitem");
#			}
#			case 'donor_id' {
#				$select = $self->dbh->selectall_arrayref("SELECT donor_id,name FROM donors_vw ORDER BY name");
#			}
#			case 'stockitem_id' {
#				$select = $self->dbh->selectall_arrayref("SELECT stockitem_id,concat(name,' (',value,')') namevalue FROM stockitems ORDER BY name");
#			}
		}
	} => 'api/buildselect';
	post '/toggle/:table/:column/:id' => (is_xhr => 1) => sub {
		my $self = shift;
		my $column = $self->param('column');
		if ( my $me = $self->db->resultset($self->param('table'))->find($self->param('id')) ) {
			$me->update({$column=>$me->$column?0:1});
			$self->render_json({update=>'ok'});
		} else {
			$self->render_json({update=>'err'});
		}
	};
	under '/grid';
	group {
		post '/:table/cell' => (is_xhr => 1) => sub {
			my $self = shift;
			my $column = $self->param('celname');
			if ( my $me = $self->db->resultset($self->param('table'))->find($self->param('id')) ) {
				switch ( $self->param('oper') ) {
					case 'edit' {
						$me->update({$column=>$self->param($column)});
						return $self->render_json({update=>'ok'});
					}
				}
			}
			$self->render_json({update=>'err'});
		};
	};
};

under '/reports';
group {
	get '/solicitation_aids';
	get '/solicitation_aids.pdf' => sub {
		my $self = shift;
		my $data = $self->db->resultset('Leader')->leaders->search({}, {prefetch=>{rotarian=>{donors=>{items=>'highbid'}}}});
		$self->respond_to(
			pdf => [$data->hashref_array],
		);
	};
	post '/solicitation_aids' => (is_xhr => 1) => sub {
		my $self = shift;
		$self->stash(format => 'json') if $self->req->is_xhr;
		my $data;
		switch ( $self->param('template') ) {
			case 'checklist' {
				$data = $self->db->resultset('Leader')->leaders->search({}, {order_by=>['me.lastname', 'rotarians.lastname'], prefetch=>'rotarians'});
			}
			case 'packet' {
				$data = $self->db->resultset('Rotarian')->search({'me.rotarian_id'=>$self->param('id')}, {order_by=>['me.lastname', 'donors.name', 'items.year'], prefetch=>{donors=>{items=>'highbid'}}});
			}
			case 'packets' {
				$data = $self->db->resultset('Leader')->leaders->search({}, {order_by=>['me.lastname', 'rotarians.lastname', 'donors.name', 'items.year'], prefetch=>{rotarians=>{donors=>{items=>'highbid'}}}});
			}
		}
		$data = $data->hashref_array;
		walk(\&with, $data);
		$self->respond_to(
			json => {json => $data},
			html => {},
		);
	};
	get '/postcards.xls' => sub {
		my $self = shift;
		$self->render_xls(
			format => 'xls',
			result => $self->db->resultset('Donor')->postcards,
		);
	};
};

under '/grid';
group {
	under '/rotarians';
	get '/' => (is_xhr => 0) => 'rotarians';
	post '/' => (is_xhr => 1) => sub {
		my $self = shift;
		$self->stash(format => 'json') if $self->req->is_xhr; # Needed because jqGrid sends multiple content-types.  https://github.com/kraih/mojo/issues/227
#		my $data = $self->db->resultset('Rotarian')->search({$self->search}, {$self->rows, $self->order_by, join=>['leader','donors'], prefetch=>['leader','donors']});
		my $data = $self->db->resultset('Rotarian')->search({$self->search}, {$self->rows, $self->order_by});
#		$data->result_class('Schema::Result::Rotarian::Three');
		$self->respond_to(
			json => {json => $data->grid},
		);
	};

	under '/donors';
	get '/' => (is_xhr => 0) => 'donors';
	post '/' => (is_xhr => 1) => sub {
		my $self = shift;
		$self->stash(format => 'json') if $self->req->is_xhr;
		my $data = $self->db->resultset('Donor')->search({$self->search}, {$self->rows, $self->order_by, prefetch=>['rotarian']})->solicit;
#		$data->result_class('Schema::Result::Donor::ManageGrid');
		$self->respond_to(
			json => {json => $data->grid},
			html => {},
		);
	};
	post '/:id' => (is_xhr => 1) => sub {
		my $self = shift;
		$self->stash(format => 'json') if $self->req->is_xhr;
		my $data = $self->db->resultset('Item')->search({donor_id=>$self->param('id')}, {$self->rows, order_by=>'year', prefetch=>['highbid']});
#		$data->result_class('Schema::Result::Donor::ManageGrid');
		$self->respond_to(
			json => {json => $data->grid},
			html => {},
		);
	};

	under '/items';
	any '/' => sub {
		my $self = shift;
		$self->stash(format => 'json') if $self->req->is_xhr;
		my $data = $self->db->resultset('Item')->search({$self->search}, {$self->rows, $self->order_by})->current_year;
		$self->respond_to(
			json => {json => $data->grid},
			html => {},
		);
	} => 'items';

	under '/stockitems';
	any '/' => sub {
		my $self = shift;
		$self->stash(format => 'json') if $self->req->is_xhr;
		$self->respond_to(
			json => {json => $self->db->resultset('Stockitem')->search({$self->search}, {$self->order_by, $self->rows})->current_year->grid},
			html => {},
		);
	} => 'stockitems';

	under '/bidders';
	any '/' => sub {
		my $self = shift;
		$self->stash(format => 'json') if $self->req->is_xhr;
		$self->respond_to(
			json => {json => $self->db->resultset('Bidder')->search({$self->search}, {$self->order_by, $self->rows})->current_year->stefan->grid},
			html => {},
		);
	} => 'bidders';
};

app->start;

##############################

sub with {
	no warnings;
	my ($container, $type, $seen, $address, $depth) = ($Data::Walk::container, $Data::Walk::type, $Data::Walk::seen, $Data::Walk::address, $Data::Walk::depth);
	return unless $type eq 'HASH';
	switch ( $_ ) {
		case 'contact1' { # Wherever a contact1 key is found, add a contact key
			$container->{contact} = join('|', grep { $_ } $container->{contact1}, $container->{contact2});
		}
	}
};

__DATA__
@@ index.html.ep
Washington Rotary Radio Auction

@@ bookmarks.html.ep
<%= link_to 'Solicitation Aids' => 'solicitation_aids' %><br />
<%= link_to 'Rotarians Grid' => 'rotarians' %><br />
<%= link_to 'Donors Grid' => 'donors' %><br />

@@ api/buildselect.html.ep
<select>
  <option value="" />
  % foreach ( @$select ) {
      <option value="<%= $_->{rotarian_id} %>"><%= $_->{name} %></option>
  % }
</select>

@@ grid.html.ep
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title><%= $title %></title>
<link   href="http://ajax.googleapis.com/ajax/libs/jqueryui/1.8/themes/base/jquery-ui.css" type="text/css" rel="stylesheet" media="all" />
<link   href="/s/css/ui.jqgrid.css" rel="stylesheet" type="text/css" media="screen" />      
<script  src="http://ajax.googleapis.com/ajax/libs/jquery/1.8/jquery.min.js" type="text/javascript"></script>
<script  src="/s/js/i18n/grid.locale-en.js" type="text/javascript"></script>
<script  src="/s/js/jquery.jqGrid.min.js" type="text/javascript"></script>  
<script  src="/s/js/jquery.json-2.3.min.js" type="text/javascript"></script>
<script  src="/s/js/jquery.maskedinput.js" type="text/javascript"></script>
<style>
    #loggedin {display:none}
</style>
<script type="text/javascript">
$(document).ready(function(){  
//    $.getJSON('pl/about', function(data) {
//        if ( data.username ) {
//            $("#loggedin").append("Logged in as " + data.username);
//        }
//        document.title = data.name + " " + data.year + (data.night?", Night " + data.night:'') + (data.live?'':' (Offline)');
//    });
    var selectBool = "1:Yes;0:No";
    var categories = ":;bank:Bank;lawyer:Lawyer;realty:Realty;doctor:Doctor;cpa:CPA;personal:Personal;esq:ESQ;seq:SEQ;insurance:Insurance";
    // Forces a specific format for a phone number.  Make sure that the
    // DB definition is varchar(14)
    function phoneMask(elem) {
        // Reference in .jqGrid {options} colModel {name:...} property with editoptions:{dataInit:___Mask} property
        $(elem).mask("(999) 999-9999");
    }
    // Pops an alert after add form indicating the item number that was just added
    function alertAddedItemNumber(response,postdata) {
        // Reference in .navGrid {add} object afterSubmit: property
        var json=response.responseText;
        var result=eval("("+json+")");
        if (result.sc) alert("Added Item Number "+result.number);
        return [result.sc,result.msg,null];
    }

    function ac_city(elem){
        $(elem).autocomplete('pl/ac/city');
        $(elem).result(function(event, data, formatted){
            if (data) {
                $('#state').val(data[1]);
                $('#zip').val(data[2]);
            }
        });
        return true;
    }

    function formatGridCells() {
        // Reference in .jqGrid {options} loadComplete: property
        $('table#list1 tbody tr td[title~="Yes"]').css('color', 'green');
        $('table#list1 tbody tr td[title~="No"]').css('color', 'red');
        $('table#list1 tbody tr td[aria-describedby="list1_items"]').css('color', 'green');
        $('table#list1 tbody tr td[aria-describedby="list1_items"][title="0"]').css('color', 'red');
    }

    function checkUpdate(response,postdata) {
        // Reference in .navGrid {add/edit/del} object afterSubmit: property
        var json=response.responseText;
        var result=eval("("+json+")");
        return [result.sc == 'true' ? true : false,result.msg,null];
    }
    jQuery.extend($.fn.fmatter , {
        // Reference in .jqGrid {options} colModel {name:...} property with formatter:'___Fmatter' property
        phoneFmatter : function(cellvalue, options, rowdata) {
            if ( cellvalue ) {
                var re = /\(?([0-9]{3})\)? ?([0-9]{3})-?([0-9]{4})/.exec(cellvalue);
                return "(" + re[1] + ") " + re[2] + "-" + re[3];
            }
            return '&nbsp;';
        },
        boolFmatter : function(cellvalue, options, rowdata) {
            if ( cellvalue == 1 ) return 'Yes';
            return 'No';
        },
        categoryFmatter : function(cellvalue, options, rowdata) {
            if ( cellvalue ) return cellvalue.charAt(0).toUpperCase() + cellvalue.slice(1);
            return '&nbsp;';
        }
    });  
    %= content grid => begin
    // Grid
    % end
});
</script>
</head>  
<body>   
<%= scalar localtime %>
<div id="loggedin"></div>
<a href="<%= url_for 'bookmarks' %>">Back to Bookmarks</a>
<table id="list1" class="scroll"></table> 
<div id="pager1" class="scroll" style="text-align:center;" />
</body>
</html>

@@ rotarians.html.ep
% extends 'grid', title=>'Rotarians';
% content grid => begin
$("#list1").jqGrid({
        // To do: run boolFmatter after update
        // To do: Escape on cell edit sometimes does not work
        url: '<%= url_for %>',
        mtype: 'POST',
        datatype: 'json',
        jsonReader: {repeatitems: false, id: "rotarian_id"},
        ajaxGridOptions: { contentType: "application/json; charset=utf-8" },
	postData: {grid: "rotarians"},
        serializeGridData: function (postData) { return $.toJSON(postData); },
        caption: "Rotarians",
        colModel:[
            {name:'rotarian_id',label:'PH#',width:100,editable:false,hidden:true},
            {name:'name',label:'Rotarian',width:200,editable:false,formatter:function(cellvalue,options,rowdata){
                    if ( cellvalue ) {
                        return '<span style="color:'+(rowdata.has_submissions >= 1 ? 'Green' : 'Red')+'">' + cellvalue + '</span>';
                    }
                    return '';
                },
                cellattr:function(rowId,val,raw,cm,rdata){
                    raw.name="Hello!";
                }
            },
            {name:'email',label:'Email',width:200,editable:false},
            {name:'phone',label:'Phone',width:200,editable:false}
        ],
        loadComplete: formatGridCells,
        recreateForm: true,
        altRows: true,
        rownumbers: true,
        rownumWidth: 50,
        scroll: false,
        rowNum: 50,
        rowList: [10, 20, 50, 100, 500, 1000, 5000, 10000],
        pager: '#pager1',
        sortname: 'lastname',
        viewrecords: true,
        height: "75\%",
        autowidth: true
    });
    $("#list1").jqGrid('navGrid','#pager1',
        {edit:false,add:false,del:false},
        // {edit}, {add}, {del}, {search}, {view}
        {},
        {},
        {},
        {
/*
            url: "<%= url_for %>",
            caption: "Search Rotarians"
*/
        },
        {
/*
            url: "<%= url_for %>/view",
            caption: "View Rotarian"
*/
        }
//    ).ajaxComplete(function(e, xhr, settings){
//        var json = $.parseJSON(xhr.responseText);
//        if ( json && json.error == "401" ) { window.location = "error.html?referer=rotarians.html;status=401"; }
//        if ( json && json.error == "403" ) { window.location = "login.html?referer=rotarians.html"; } }
    );
% end

@@ donors.html.ep
% extends 'grid', title=>'Donors';
% content grid => begin
$("#list1").jqGrid({
        // To do: run boolFmatter after update
        // To do: Escape on cell edit sometimes does not work
        url: '<%= url_for %>',
        postData: {grid: "donors"},
        mtype: 'POST',
        datatype: 'json',
        jsonReader: {repeatitems: false, id: "donor_id", subgrid: {root: "rows", repeatitems: true}},
        ajaxGridOptions: { contentType: "application/json; charset=utf-8" },
        serializeGridData: function (postData) { return $.toJSON(postData); },
        caption: "Donors",
        colModel:[
            {name:'chamberid',label:'C-ID',width:30,hidden:true,editable:true,editrules:{number:true,minValue:1,maxValue:9999}},
            {name:'phone',label:'Phone',width:70,editable:true,editoptions:{dataInit:phoneMask},editrules:{required:true},formoptions:{elmsuffix:'(*)'},formatter:'phoneFmatter'},
            {name:'category',label:'Category',width:40,editable:true,edittype:'select',editoptions:{multiple:false,value:categories},formatter:'categoryFmatter'},
            {name:'name',label:'Donor',width:200,editable:true,editrules:{required:true},formoptions:{elmsuffix:'(*)'}},
            {name:'contact',label:'Contact',width:100,editable:true,editrules:{required:true},formoptions:{elmsuffix:'(*)'}},
            {name:'address',label:'Address',width:100,search:false,editable:true,editrules:{required:true},formoptions:{elmsuffix:'(*)'}},
            {name:'city',label:'City',width:60,editable:true,editoptions:{dataInit:ac_city}},
            {name:'state',label:'State',width:60,editable:true,hidden:true,editrules:{edithidden:true}},
            {name:'zip',label:'Zip',width:60,editable:true,hidden:true,editrules:{edithidden:true}},
            {name:'email',label:'Email',width:60,search:false,editable:true,hidden:true,editrules:{email:true,edithidden:true,required:false}},
            {name:'donorurl',label:'URL',width:60,search:false,editable:true,hidden:true,editrules:{url:true,edithidden:true,required:false}},
            {name:'advertisement',label:'Advertisement',hidden:true,search:false,editable:true,edittype:'textarea',editrules:{edithidden:true}},
            {name:'solicit',label:'Solicit',width:25,editable:true,edittype:'select',editoptions:{multiple:false,value:selectBool},formatter:'boolFmatter'},
            {name:'ly_items',label:'LY#',width:25,editable:false,sortable:false},
            {name:'rotarian',label:'Rotarian',width:100,editable:true,edittype:'select',editoptions:{multiple:false,dataUrl:'/api/buildselect/rotarians'}},
            {name:'comments',label:'Comments',width:100,search:false,editable:true}
        ],
        subGrid: true,
        subGridRowExpanded: function(subgrid_id, row_id) {
            var subgrid_table_id;
            subgrid_table_id = subgrid_id+"_t";
            jQuery("#"+subgrid_id).html("<table id='"+subgrid_table_id+"' class='scroll'></table>");
            jQuery("#"+subgrid_table_id).jqGrid({
                url:"<%= url_for %>/"+row_id,
                mtype: 'POST',
                datatype: "json",
                jsonReader: {repeatitems: false, id: "donor_id", subgrid: {root: "rows", repeatitems: true}},
                colModel: [
                    {name:"year",label:"Year",width:130},
                    {name:"sold",label:"Night Sold",width:130},
                    {name:"value",label:"Value",width:130},
                    {name:"highbid",label:"High Bid",width:130},
                    {name:"bellringer",label:"Bellringer",width:130},
                ],
                height: '100%',
                rowNum:20,
            });
        },
        cellEdit: true,
        cellurl: "<%= url_for '/api/grid/Donor/cell' %>",
        beforeSubmitCell: function(rowid,celname,value,iRow,iCol){
            if (celname=="rotarian"){
                return {celname:"rotarian_id",rotarian_id:value};
            } else {
                return {celname:celname};
            }
        },
        loadComplete: formatGridCells,
        recreateForm: true,
        altRows: true,
        rownumbers: true,
        rownumWidth: 50,
        scroll: false,
        rowNum: 50,
        rowList: [10, 20, 50, 100, 500, 1000, 5000, 10000],
        pager: $('#pager1'),
        sortname: 'name',
        viewrecords: true,
        height: "75\%",
        autowidth: true
    }).navGrid('#pager1',
        {edit:true,add:true,del:true},
        // {edit}, {add}, {del}, {search}, {view}
        {
            url: "/donors/edit",
            editCaption: "Edit Donor",
            width: 700,
            closeOnEscape: true,
            closeAfterEdit: true,
            afterSubmit: checkUpdate
        },
        {
            url: "/donors/add",
            addCaption: "Add Donor",
            width: 700,
            closeOnEscape: true,
            afterSubmit: checkUpdate
        },
        {
            url: "/donors/del",
            caption: "Delete Donor",
            msg: "Deleted selected donor(s)?",
            afterSubmit: checkUpdate
        },
        {
            url: "/donors/search",
            caption: "Search Donor"
        },
        {
            url: "/donors/view",
            caption: "View Donor"
        }
//    ).ajaxComplete(function(e, xhr, settings){
//        var json = $.parseJSON(xhr.responseText);
//        if ( json && json.error == "401" ) { window.location = "error.html?referer=donors.html;status=401"; }
//        if ( json && json.error == "403" ) { window.location = "login.html?referer=donors.html"; } }
    );
% end

@@ solicitation_aids.html.ep
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html;charset=iso-8859-1" />
<title>Rotarian Solicitation Aids</title>
<style type="text/css">
	* {
		font-family: Verdana;
		font-size: 11px;
	}
	table,td,tr {
		padding: 0px;
		margin: 0px;
		spacing: 0px;
		vertical-align: top;
		border-collapse:collapse;
	}
	table.spread,td.spread,tr.spread {
		padding: 5px;
		margin: 5px;
		spacing: 5px;
		vertical-align: top;
		border-collapse:collapse;
	}
	table.leaders {
		border-left: 1px solid black;
		border-top: 1px solid black;
		border-right: 1px solid black;
	}
	table.leadermembers {
		border: 1px solid black;
	}
	table.rotarians {
		border-left: 1px solid black;
		border-top: 1px solid black;
		border-right: 1px solid black;
	}
	table.donors {
		border: 1px solid black;
	}
	table.donors td.donor {
		padding: 3px;
		border-right: 1px solid black;
	}
	table.donors td.advertisement {
		padding: 10px;
		vertical-align: middle;
		width: 300px;
	}
	table.items td {
		padding: 3px;
		border: 1px solid black;
	}
	tr.row {border: 1px solid black}
	@media print {
		table.leadermembers {page-break-after:always}
		table.donors {page-break-after:always}
	}
	.link {color:blue;cursor:pointer;text-decoration:underline}
</style>
<script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.7.1/jquery.min.js"></script>
<script type="text/javascript" src="/s/js/jquery-jtemplates.js"></script>
<script type="text/javascript" src="/s/js/jquery.blockUI.js"></script>
<script type="text/javascript">
$(document).ready(function(){
	function packet_link (id) {
		$(document).on("click", "#link_"+id, function(){
			$("#packet").setTemplateElement("t_packet", null, {runnable_functions: true});
			$("#packet").processTemplateURL("<%= url_for %>", null, {
				type: 'POST',
				data: {template: "packet", id: id}
			});
		});
		true;
	}

	$("#checklist").setTemplateElement("t_checklist", null, {runnable_functions: true});
	$("#checklist").setParam('packet_link', packet_link);

	$("#checklist").processTemplateURL("<%= url_for %>", null, {
		type: 'POST',
		data: {template: "checklist"}
	});
	$("#all").click(function(){
		$("#checklist").block({ message: '<h1><img src="/s/img/busy.gif" /> Just a moment...</h1>' });
		$("#packet").setTemplateElement("t_packets", null, {runnable_functions: true});
		$("#packet").processTemplateURL("<%= url_for %>", null, {
			type: 'POST',
			data: {template: "packets"},
			on_complete: function(){
				$("#checklist").unblock();
			}
		});
	});
});
function UpdateSubmissions(id) {
    $.post("<%= url_for '/api/toggle/Rotarian/has_submissions/' %>"+id);
}
function UpdateLeader(id) {
    $.post("<%= url_for '/api/toggle/Rotarian/lead/' %>"+id);
}
</script>
</head>
<body>
	<div id="loggedin"></div>
	<a href="<%= url_for 'bookmarks' %>">Back to Bookmarks</a>
	<div id="all" class="link">All Packets</div>
	<a name="top">

	<div id="checklist" class="jTemplatesTest"></div>
	<hr />
	<div id="packet" class="jTemplatesTest"></div>

	<!-- Template content -->
	<textarea id="t_checklist" style="display:none">
		<h1>Rotarian Submissions</h1>
		<table class="spread">
		<tr class="spread">
		{#foreach $T as leader}
		<td class="spread">
		<table class="leaders"><tr><td class="leader">{$T.leader.lastname}, {$T.leader.firstname}</td></tr></table>
		<table class="leadermembers">
			{#foreach $T.leader.rotarians as rotarian}
			{#if $T.rotarian.lastname}
			<tr class="">
				<td class="" width=150><div id="link_{$T.rotarian.rotarian_id}" class="link">{$T.rotarian.lastname}, {$T.rotarian.firstname}</div></td>
				<td><input type="checkbox" onclick="UpdateSubmissions('{$T.rotarian.rotarian_id}')" {($T.rotarian.has_submissions >= 1) ? "CHECKED" : ""} /></td>
			</tr>
			{$P.packet_link($T.rotarian.rotarian_id)}
			{#else}
			<tr class="">
				<td class="" width=150>None assigned</td>
			</tr>
			{#/if}
			{#/for}
		</table>
		</td>
		{#if (1+$T.leader$index) % 6 == 0}</tr><tr class="spread">{#/if}
		{#/for}
		</tr>
		</table>
	</textarea>

	<textarea id="t_packet" style="display:none">
		<h1>Solicitation Packets</h1>
		{#foreach $T as rotarian}
		<table class="rotarians">
			<tr>
				<td class="rotarian"><a href="#top"><img src="/s/img/arrow-up-blue.png" width="16" height="16" /></a>{$T.rotarian.lastname}, {$T.rotarian.firstname}<input type="checkbox" onclick="UpdateLeader('{$T.rotarian.rotarian_id}')" {($T.rotarian.lead == 1) ? "CHECKED" : ""} /></td>
				<table class="donors">
					{#foreach $T.rotarian.donors as donor}
					<tr class="row">
						<td class="donor"><b>{#if $T.donor.items.length >= 1}<img src="/s/img/yes.gif" />{#else}<img src="/s/img/no.gif" />{#/if}</b>{$T.donor.name}<br />{#if $T.donor.contact && $T.donor.contact != $T.donor.name}{$T.donor.contact}<br />{#/if}{#if $T.donor.address && $T.donor.address != ""}{$T.donor.address}{#if $T.donor.city} ({$T.donor.city}){#/if}<br />{#/if}{#if $T.donor.phone || $T.donor.email}{$T.donor.phone||""} {$T.donor.email||""}{#/if}</td>
						<td class="items">
						<table class="items">
						{#foreach $T.donor.items as item}
						<tr>
							<td class="year">{$T.item.year}</td>
							<td class="item">{$T.item.number}: {$T.item.name}{#if $T.item.stockitem_id} <img src="/s/img/barcode.png" />{#/if}</td>
							<td class="value">${$T.item.value} (${$T.item.highbid.bid}){#if $T.item.bellringer} <img src="/s/img/bell.png" />{#/if}</td>
						</tr>
						{#else}
						<tr><td>[ No donation found ]</td></tr>
						{#/for}
						</table>
						</td>
						<td class="advertisement">{$T.donor.advertisement||"[ No Advertisement on file ]"}</td>
					</tr>
					{#/for}
				</table>
				<br />
			</tr>
		</table>
		{#/for}
	</textarea>

	<textarea id="t_packets" style="display:none">
		<h1>All Solicitation Packets</h1>
		{#foreach $T as leader}
		<h4>{$T.leader.lastname}, {$T.leader.firstname}</h4>
		{#foreach $T.leader.rotarians as rotarian}
		<table class="rotarians">
			<tr>
				<td class="rotarian"><a href="#top"><img src="/s/img/arrow-up-blue.png" width="16" height="16" /></a>{$T.rotarian.lastname}, {$T.rotarian.firstname}<input type="checkbox" onclick="UpdateLeader('{$T.rotarian.rotarian_id}')" {($T.rotarian.lead == 1) ? "CHECKED" : ""} /></td>
				<table class="donors">
					{#foreach $T.rotarian.donors as donor}
					<tr class="row">
						<td class="donor">
							{#if $T.donor.items.length >= 1}<img src="/s/img/yes.gif" />{#else}<img src="/s/img/no.gif" />{#/if}
							{$T.donor.name}<br />
							{#if $T.donor.contact && $T.donor.contact != $T.donor.name}{$T.donor.contact}<br />{#/if}
							{#if $T.donor.address && $T.donor.address != ""}{$T.donor.address}{#if $T.donor.city} ({$T.donor.city}){#/if}<br />{#/if}
							{#if $T.donor.phone || $T.donor.email}{$T.donor.phone||""} {$T.donor.email||""}{#/if}
						</td>
						<td class="items">
						<table class="items">
						{#foreach $T.donor.items as item}
						<tr>
							<td class="year">{$T.item.year}</td>
							<td class="item">{$T.item.number}: {$T.item.name}{#if $T.item.stockitem_id} <img src="/s/img/barcode.png" />{#/if}</td>
							<td class="value">${$T.item.value} (${$T.item.highbid.bid}){#if $T.item.bellringer} <img src="/s/img/bell.png" />{#/if}</td>
						</tr>
						{#else}
						<tr><td>[ No donation found ]</td></tr>
						{#/for}
						</table>
						</td>
						<td class="advertisement">{$T.donor.advertisement||"[ No Advertisement on file ]"}</td>
					</tr>
					{#/for}
				</table>
				<br />
			</tr>
		</table>
		{#/for}
		<hr />
		{#/for}
	</textarea>
</body>
</html>
