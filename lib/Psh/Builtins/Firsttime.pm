package Psh::Builtins::Firsttime;
use strict;

use Psh::Util ':all';

=item * C<firsttime> [n]

firsttime is a setup utility which should be used by first-time
psh users. It will parse existing shell rc files and try to
convert as much settings as possible and generate a .pshrc
file. It currently can only convert aliases, bash completions
and environment variables.

=cut

my (%aliases,$env,$complete);

sub bi_firsttime
{
	my $line;

	print <<EOT;
Welcome to the Firsttime Setup Utility!

This utility will try to setup an initial .pshrc file for you.
You can interrupt the process anytime using ^C

EOT

	my $home=Psh::OS::get_home_dir();

	unless ($home) {
		print <<EOT;
You unfortunately do not have a home directory where the .pshrc file could
be stored. Please set the environment variable HOME to a sensible value.
EOT
        return undef;
    }

	my $tmp;

	$tmp=File::Spec->catfile($home,'.pshrc');
	if (-r $tmp) {
		$line=_prompt('yn',
					 "Warning - you already have a .pshrc file!!!!\n".
					  "Do you really want to continue (y/n)? ");
		return undef if $line eq 'n';
	}

	my $text= "# This file was autogenerated by psh firsttime\n\n";
	print "Please press ENTER to start...\n";
	$line=<STDIN>;

	%aliases=();
	$env='';
	$complete='';

	my @sh_files=qw(.bashrc .bash_login .login);
	my @csh_files=qw(.cshrc);

	# .alias files usually _only_ contain aliases and functions
	# so we offer to source them
	$tmp=File::Spec->catfile($home,'.alias');
	if (-r $tmp) {
		$line=_prompt('ics',
					  "We have found a .alias file. Do you want to\n".
					  "(c)all it from your .pshrc file\n".
					  "(i)nsert it into your .pshrc file\n".
					  "(s)kip ? ");

		if ($line eq 'c') {
			$text.="source ~/.alias\n";
		} elsif ($line eq 'i') {
			_parse_sh_file($tmp);
		}
	}

	$line=_prompt('cs',"Parse (s) bash/sh files or\n      (c) csh files? ");
	if ($line eq 's') {
		foreach my $file (@sh_files) {
			$tmp=File::Spec->catfile($home,$file);
			$line=_prompt('yn',
						  "Found file $file - parse it (y/n)? ");
			if ($line eq 'y') {
				_parse_sh_file($tmp);
			}
		}
	} else {
		foreach my $file (@csh_files) {
			$tmp=File::Spec->catfile($home,$file);
			$line=_prompt('yn',
						  "Found file $file - parse it (y/n)? ");
			if ($line eq 'y') {
				_parse_csh_file($tmp);
			}
		}
	}

	$text.=_generate_stuff();

	print "The setup process is finished now.\n";
	print "Press ENTER to save to $home/.pshrc now or ^C to stop.\n";
	$line=<STDIN>;
	open(FILE,"> $home/.pshrc");
	print FILE $text;
	close(FILE);
	print "$home/.pshrc saved\n";
	return undef;
}

sub _prompt {
	my $allowed= shift;
	$allowed= "^[$allowed]\$";
	my $text= shift;
	my $line='';

	do {
		print $text;
		$line=<STDIN>;
	} while (!$line || lc($line) !~ $allowed);
	chomp $line;
	return lc($line);
}

sub _generate_stuff {
	my $text='';
	my ($key,$value);

	$text=$env.$complete;
	while ( ($key,$value)= each %aliases) {
		$text.="alias $key=$value\n";
	}
	return $text;
}

sub _parse_sh_file {
	my $file= shift;
	my $text='';
	open(FILE,"< $file");
	while (<FILE>) {
		my $line=$_;
		chomp $line;
		next if $line=~/^\s*#/;
		if ($line=~/^\s*alias (\S+)\=(.+)$/) {
			my $key= $1;
			my $value= $2;
			if (exists $aliases{$key}) {
				print STDERR "Warning: alias $key redefined.\n";
			}
			$aliases{$key}=$value;
		} elsif ($line=~/^\s*function (\S+) \{/) {
			print STDERR "Warning: Could not convert function $1.\n";
		} elsif ($line=~/^\s*(\S+)\=(.*)$/) {
			my $key= uc($1);
			my $value= _change_env_value($2);
			$env.="setenv $key=\"$value\"\n";
		} elsif ($line=~/^\s*export (\S+)\=(.+)$/) {
			my $key= uc($1);
			my $value= _change_env_value($2);
			$env.="export $key=\"$value\"\n";
		}

	}
	close(FILE);
	return undef;
}


sub _parse_csh_file {
	my $file= shift;
	my $text='';
	open(FILE,"< $file");
	while (<FILE>) {
		my $line=$_;
		chomp $line;
		next if $line=~/^\s*#/;
		if ($line=~/^\s*alias (\S+)\s+(.+)$/) {
			my $key= $1;
			my $value= $2;
			if (exists $aliases{$key}) {
				print STDERR "Warning: alias $key redefined.\n";
			}
			$aliases{$key}=$value;
		} elsif ($line=~/^\s*setenv\s+(\S+)\s+(.+)$/) {
			my $key= uc($1);
			my $value= _change_env_value($2);
			$env.="setenv $key=\"$value\"\n";
		} elsif ($line=~/^\s*set\s+(\S+)\=\s*["]([^\"]+)["]\s*$/ ||
				 $line=~/^\s*set\s+(\S+)\=\s*[']([^\']+)[']\s*$/ ||
				 $line=~/^\s*set\s+(\S+)\=\s*(\([^\']+\))\s*$/ ||
				 $line=~/^\s*set\s+(\S+)\=([^#\s]+)\s*/) {
			my $key= uc($1);
			my $value= _change_env_value($2);
			$env.="setenv $key=\"$value\"\n";
		}

	}
	close(FILE);
	return undef;
}

sub _change_env_value
{
	my $val= shift;
	$val=~s/\$([a-zA-Z0-9_]+)/\$ENV\{$1\}/g;
	return $val;
}

1;

# Local Variables:
# mode:perl
# tab-width:4
# indent-tabs-mode:t
# c-basic-offset:4
# perl-label-offset:0
# perl-indent-level:4
# cperl-indent-level:4
# cperl-label-offset:0
# End:
