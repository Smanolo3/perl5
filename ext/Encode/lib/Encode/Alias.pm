package Encode::Alias;
use strict;
use Encode;
our $VERSION = do { my @r = (q$Revision: 1.2 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };
our $DEBUG = 0;
require Exporter;

our @ISA = qw(Exporter);

# Public, encouraged API is exported by default

our @EXPORT = 
    qw (
	define_alias
	find_alias
	);

our @Alias;  # ordered matching list
our %Alias;  # cached known aliases

sub find_alias
{
    my $class = shift;
    local $_ = shift;
    unless (exists $Alias{$_})
    {
	for (my $i=0; $i < @Alias; $i += 2)
	{
	    my $alias = $Alias[$i];
	    my $val   = $Alias[$i+1];
	    my $new;
	    if (ref($alias) eq 'Regexp' && $_ =~ $alias)
	    {
		$DEBUG and warn "eval $val";
		$new = eval $val;
		# $@ and warn "$val, $@";
	    }
	    elsif (ref($alias) eq 'CODE')
	    {
		$DEBUG and warn "$alias", "->", "($val)";
		$new = $alias->($val);
	    }
	    elsif (lc($_) eq lc($alias))
	    {
		$new = $val;
	    }
	    if (defined($new))
	    {
		next if $new eq $_; # avoid (direct) recursion on bugs
		$DEBUG and warn "$alias, $new";
		my $enc = (ref($new)) ? $new : Encode::find_encoding($new);
		if ($enc)
		{
		    $Alias{$_} = $enc;
		    last;
		}
	    }
	}
    }
    if ($DEBUG){
	my $name;
	if (my $e = $Alias{$_}){
	    $name = $e->name;
	}else{
	    $name = "";
	}
	warn "find_alias($class, $_)->name = $name";
    }
    return $Alias{$_};
}

sub define_alias
{
    while (@_)
    {
	my ($alias,$name) = splice(@_,0,2);
	unshift(@Alias, $alias => $name);   # newer one has precedence
	# clear %Alias cache to allow overrides
	if (ref($alias)){
	    my @a = keys %Alias;
	    for my $k (@a){
		if (ref($alias) eq 'Regexp' && $k =~ $alias)
		{
		    $DEBUG and warn "delete \$Alias\{$k\}";
		    delete $Alias{$k};
		}
		elsif (ref($alias) eq 'CODE')
		{
		    $DEBUG and warn "delete \$Alias\{$k\}";
		    delete $Alias{$alias->($name)};
		}
	    }
	}else{
	    $DEBUG and warn "delete \$Alias\{$alias\}";
	    delete $Alias{$alias};
	}
    }
}

# Allow latin-1 style names as well
                     # 0  1  2  3  4  5   6   7   8   9  10
our @Latin2iso = ( 0, 1, 2, 3, 4, 9, 10, 13, 14, 15, 16 );
# Allow winlatin1 style names as well
our %Winlatin2cp   = (
		      'latin1'     => 1252,
		      'latin2'     => 1250,
		      'cyrillic'   => 1251,
		      'greek'      => 1253,
		      'turkish'    => 1254,
		      'hebrew'     => 1255,
		      'arabic'     => 1256,
		      'baltic'     => 1257,
		      'vietnamese' => 1258,
		     );

init_aliases();

sub undef_aliases{
    @Alias = ();
    %Alias = ();
}

sub init_aliases
{
    undef_aliases();
    # 'C' => 'US-ascii' so you can feed default locale directly.
    define_alias('C' => 'US-ascii');
    # Allow variants of iso-8859-1 etc.
    define_alias( qr/\biso[-_]?(\d+)[-_](\d+)$/i => '"iso-$1-$2"' );

    # At least HP-UX has these.
    define_alias( qr/\biso8859(\d+)$/i => '"iso-8859-$1"' );

    # More HP stuff.
    define_alias( qr/\b(?:hp-)?(arabic|greek|hebrew|kana|roman|thai|turkish)8$/i => '"${1}8"' );

    # The Official name of ASCII.
    define_alias( qr/\bANSI[-_]?X3\.4[-_]?1968$/i => '"ascii"' );

    # This is a font issue, not an encoding issue.
    # (The currency symbol of the Latin 1 upper half
    #  has been redefined as the euro symbol.)
    define_alias( qr/^(.+)\@euro$/i => '"$1"' );

    define_alias( qr/\b(?:iso[-_]?)?latin[-_]?(\d+)$/i 
		  => '"iso-8859-$Encode::Alias::Latin2iso[$1]"' );

    define_alias( qr/\bwin(latin[12]|cyrillic|baltic|greek|turkish|
			 hebrew|arabic|baltic|vietnamese)$/ix => 
		  '"cp" . $Encode::Alias::Winlatin2cp{lc($1)}' );

    # Common names for non-latin prefered MIME names
    define_alias( 'ascii'    => 'US-ascii',
		  'cyrillic' => 'iso-8859-5',
		  'arabic'   => 'iso-8859-6',
		  'greek'    => 'iso-8859-7',
		  'hebrew'   => 'iso-8859-8',
		  'thai'     => 'iso-8859-11',
		  'tis620'   => 'iso-8859-11',
		  );

    # At least AIX has IBM-NNN (surprisingly...) instead of cpNNN.
    # And Microsoft has their own naming (again, surprisingly).
    # And windows-* is registered in IANA! 
    define_alias( qr/\b(?:ibm|ms|windows)[-_]?(\d\d\d\d?)$/i => '"cp$1"');

    # Sometimes seen with a leading zero.
    define_alias( qr/\bcp037\b/i => '"cp37"');

    # Mac Mappings
    define_alias( qr/\bmacIcelandic$/i => '"macIceland"');
    define_alias( qr/^mac_(.*)$/i => '"mac$1"');
    # Ououououou.
    define_alias( qr/\bmacRomanian$/i => '"macRumanian"');

# Standardize on the dashed versions.
    # define_alias( qr/\butf8$/i  => 'utf-8' );
    define_alias( qr/\bkoi8r$/i => 'koi8-r' );
    define_alias( qr/\bkoi8u$/i => 'koi8-u' );

    unless ($Encode::ON_EBCDIC){
        # for Encode::CN
	define_alias( qr/\beuc.*cn$/i        => '"euc-cn"' );
	define_alias( qr/\bcn.*euc$/i        => '"euc-cn"' );
	# define_alias( qr/\bGB[- ]?(\d+)$/i => '"euc-cn"' )
	# CP936 doesn't have vendor-addon for GBK, so they're identical.
	define_alias( qr/^gbk$/i => '"cp936"');
	# This fixes gb2312 vs. euc-cn confusion, practically
	define_alias( qr/\bGB[-_ ]?2312(?:\D.*$|$)/i => '"euc-cn"' );
	# for Encode::JP
	define_alias( qr/\bjis$/i            => '"7bit-jis"' );
	define_alias( qr/\beuc.*jp$/i        => '"euc-jp"' );
	define_alias( qr/\bjp.*euc$/i        => '"euc-jp"' );
	define_alias( qr/\bujis$/i           => '"euc-jp"' );
	define_alias( qr/\bshift.*jis$/i     => '"shiftjis"' );
	define_alias( qr/\bsjis$/i           => '"shiftjis"' );
        # for Encode::KR
	define_alias( qr/\beuc.*kr$/i        => '"euc-kr"' );
	define_alias( qr/\bkr.*euc$/i        => '"euc-kr"' );
	# This fixes ksc5601 vs. euc-kr confusion, practically
        define_alias( qr/(?:x-)?uhc$/i            => '"cp949"' );
        define_alias( qr/(?:x-)?windows-949$/i    => '"cp949"' );
        define_alias( qr/\bks_c_5601-1987$/i      => '"cp949"' );
        # for Encode::TW
	define_alias( qr/\bbig-?5$/i		  => '"big5"' );
	define_alias( qr/\bbig5-hk(?:scs)?$/i	  => '"big5-hkscs"' );
    }

    # At last, Map white space and _ to '-'
    define_alias( qr/^(\S+)[\s_]+(.*)$/i => '"$1-$2"' );
}

1;
__END__

# TODO: HP-UX '8' encodings arabic8 greek8 hebrew8 kana8 thai8 turkish8
# TODO: HP-UX '15' encodings japanese15 korean15 roi15
# TODO: Cyrillic encoding ISO-IR-111 (useful?)
# TODO: Armenian encoding ARMSCII-8
# TODO: Hebrew encoding ISO-8859-8-1
# TODO: Thai encoding TCVN
# TODO: Vietnamese encodings VPS
# TODO: Mac Asian+African encodings: Arabic Armenian Bengali Burmese
#       ChineseSimp ChineseTrad Devanagari Ethiopic ExtArabic
#       Farsi Georgian Gujarati Gurmukhi Hebrew Japanese
#       Kannada Khmer Korean Laotian Malayalam Mongolian
#       Oriya Sinhalese Symbol Tamil Telugu Tibetan Vietnamese

=head1 NAME

Encode::Alias - alias defintions to encodings

=head1 SYNOPSIS

  use Encode;
  use Encode::Alias;
  define_alias( newName => ENCODING);

=head1 DESCRIPTION

Allows newName to be used as an alias for ENCODING. ENCODING may be
either the name of an encoding or an encoding object (as described 
in L<Encode>).

Currently I<newName> can be specified in the following ways:

=over 4

=item As a simple string.

=item As a qr// compiled regular expression, e.g.:

  define_alias( qr/^iso8859-(\d+)$/i => '"iso-8859-$1"' );

In this case if I<ENCODING> is not a reference it is C<eval>-ed to
allow C<$1> etc. to be substituted.  The example is one way to alias
names as used in X11 fonts to the MIME names for the iso-8859-*
family.  Note the double quote inside the single quote.

If you are using a regex here, you have to use the quotes as shown or
it won't work.  Also note that regex handling is tricky even for the
experienced.  Use it with caution.

=item As a code reference, e.g.:

  define_alias( sub { return /^iso8859-(\d+)$/i ? "iso-8859-$1" : undef } , '');


In this case C<$_> will be set to the name that is being looked up and
I<ENCODING> is passed to the sub as its first argument.  The example
is another way to alias names as used in X11 fonts to the MIME names
for the iso-8859-* family.

=back

=head2  Alias overloading

You can override predefined aliases by simply applying define_alias().
New alias is always evaluated first and when neccessary define_alias()
flushes internal cache to make new definition available.

  # redirect  SHIFT_JIS to MS/IBM Code Page 932, which is a
  # superset of SHIFT_JIS

  define_alias( qr/shift.*jis$/i  => '"cp932"' );
  define_alias( qr/sjis$/i        => '"cp932"' );

If you want to zap all predefined aliases, you can

  Encode::Alias->undef_aliases;

to do so.  And

  Encode::Alias->init_aliases;

gets factory setting back.


=head1 SEE ALSO

L<Encode>, L<Encode::Supported>

=cut

