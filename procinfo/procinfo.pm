package VMS::ProcInfo;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;
require DynaLoader;

@ISA = qw(Exporter DynaLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw();
@EXPORT_OK = qw(&proc_info_names        &get_all_proc_info_items
                &get_one_proc_info_item &decode_proc_info_bitmap);
$VERSION = '1.04';

bootstrap VMS::ProcInfo $VERSION;

# Preloaded methods go here.
sub new {
  my($pkg,$pid) = @_;
  my $self = { __PID => $pid || $$ };
  bless $self, $pkg; 
}

sub one_info { get_one_proc_info_item($_[0]->{__PID}, $_[1]); }
sub all_info { get_all_proc_info_items($_[0]->{__PID}) }

sub TIEHASH { my $obj = new VMS::ProcInfo @_; $obj; }
sub FETCH   { $_[0]->one_info($_[1]); }
sub EXISTS  { grep(/$_[1]/, proc_info_names()) }

# Can't STORE, DELETE, or CLEAR--this is readonly. We'll Do The Right Thing
# later, when I know what it is...
#sub STORE   {
#  my($self,$priv,$val) = @_;
#  if (defined $val and $val) { $self->add([ $priv ],$self->{__PRMFLG});    }
#  else                       { $self->remove([ $priv ],$self->{__PRMFLG}); }
#}
#sub DELETE  { $_[0]->remove([ $_[1] ],$_[0]->{__PRMFLG}); }
#sub CLEAR   { $_[0]->remove([ keys %{$_[0]->current_privs} ],$_[0]->{__PRMFLG}) }

sub FIRSTKEY {
  $_[0]->{__PROC_INFO_ITERLIST} = [ proc_info_names() ];
  $_[0]->one_info(shift @{$_[0]->{__PROC_INFO_ITERLIST}});
}
sub NEXTKEY { $_[0]->one_info(shift @{$_[0]->{__PROC_INFO_ITERLIST}}); }

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

VMS::ProcInfo - Perl extension to retrieve lots of process info for a process.

=head1 SYNOPSIS

  use VMS::ProcInfo;

Routine to return a reference to a hash with all the process info for the
process loaded into it:

  $procinfo = VMS::ProcInfo::get_all_proc_info_items(pid);
  $diolimit = $procinfo->{DIOLM};

Fetch a single piece of info:

  $diolm = VMS::ProcInfo::get_one_proc_info_item(pid, "DIOLM");

Decode a bitmap into a hash filled with names, with their values set to
true or false based on the bitmap.

  $hashref = VMS::ProcInfo::decode_proc_info_bitmap("CREPRC_FLAGS", Bitmap);
  $hashref->{BATCH};

Get a list of valid info names:

  @InfoNames = VMS::ProcInfo::proc_info_names;

Tied hash interface:
  
  tie %procinfohash, VMS::ProcInfo<, pid>;
  $diolm = $procinfohash{DIOLM};

Object access:

  $procinfoobj = new VMS::ProcInfo <pid>;
  $diolm = $procinfoobj->one_info("DIOLM");
  $hashref = $procinfoobj->all_info();

=head1 DESCRIPTION

Retrieve info for a process. Access is via function call, object
and method, or tied hash. Choose your favorite.

Note that this module does not completely duplicate the DCL F$GETJPI
lexical function.  Amongst other things, it doesn't return quota or
rightslist info. Quick rule of thumb is only single pieces of info are
returned.

=head1 BUGS

May leak memory. May not, though.

=head1 LIMITATIONS

Quadword values are returned as string values rather than integers.

Privilege info's not returned. Use VMS::Priv for that.

List info (rightslist and exceptions vectors) are not returned.

The bitmap decoder doesn't grok the CURRENT_USERCAP_MASK, MSGMASK, or
PERMANENT_USERCAP_MASK fields, as I don't know where the bitmask defs for
them are in the header files. When I do, support will get added.

=head1 AUTHOR

Dan Sugalski <sugalsd@lbcc.cc.or.us>

=head1 SEE ALSO

perl(1), VMS::Quota.

=cut
