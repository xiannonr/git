#!/usr/bin/perl

sub solveLinearEquation ($$) {
	my $M = $_[0];
	my $b = $_[1];
	my $n = scalar(@$M);
	for (my $i = 0; $i < $n - 1; $i++) {
		my $pivot = $i;
		for (my $j = $i + 1; $j < $n; $j++) {
			if (abs($$M[$pivot][$i]) < abs($$M[$j][$i])) {
				$pivot = $j;
			}
		}
		if ($pivot != $i) {
			my $row = $$M[$pivot];
			$$M[$pivot] = $$M[$i];
			$$M[$i] = $row;
			$row = $$b[$pivot];
			$$b[$pivot] = $$b[$i];
			$$b[$i] = $row;
		}
		if ($$M[$i][$i] == 0) {
			die "Need a full-rank matrix";
		}
		for (my $j = $i + 1; $j < $n; $j++) {
			my $factor = $$M[$j][$i] / $$M[$i][$i];
			$$b[$j] -= $factor * $$b[$i];
			# skipping: M[j][i] -= factor * M[i][i]
			for (my $k = $i + 1; $k < $n; $k++) {
				$$M[$j][$k] -= $factor * $$M[$i][$k];
			}
		}
	}
	for (my $i = $n - 1; $i >= 0; $i--) {
		$$b[$i] /= $$M[$i][$i];
		# skipping: M[i][i] = 1;
		for (my $j = 0; $j < $i; $j++) {
			# skipping: M[j][i] = 0;
			$$b[$j] -= $$M[$j][$i] * $$b[$i];
		}
	}
	return b;
};

sub is_nonnegative ($) {
	my $x = $_[0];
	my $n = scalar(@$x);

	for (my $i = 0; $i < $n; $i++) {
		return 0 if ($$x[$i] < 0);
	}

	return 1;
}

sub fit_okay ($$$) {
	my ($f, $x, $expected) = ($_[0], $_[1], $_[2]);

	my $actual = $f->($x);
	return $actual < $expected * 1.1 && $actual > $expected * 0.9;
}

sub extrapolate ($$) {
	my ($x, $y) = ($_[0], $_[1]);
	# Least Squares Fit:
	#
	# Given a series (x_i, y_i), find factors a_j for a linear combination
	# F(x) = Sum_j a_j * f_j(x) such that G = Sum_i (F(x_i) - y_i)^2 is
	# minimal.
	#
	# A necessary (and as it turns out, usually sufficient) condition is
	# that the derivative dG / da_j = 0 for all j. This derivative
	# evaluates to 2 * Sum_i (F(x_i) - y_i) * f_j(x_i). Hence we simply
	# build the linear equation M * a = b where
	#
	# a is the vector (a_j), b is the vector (Sum_i y_i * f_j(x_i)) and
	# m is a matrix with the entries m_(k,l) = Sum_i f_k(x_i) * f_l(x_i).
	#
	# In this instance, we choose f_j(x) as 1, x, x^2 and x * log x, for
	# j = 0, 1, 2, and 3, respectively.
	#
	# We use the jack-knifing method to avoid overfitting: we build the
	# model from the first n-1 samples and then compare the prediction with
	# the actual last sample. If the difference is too large (>10%), we
	# reject it.

	my $n = scalar(@$x);
	my ($yf0, $yf1, $yf2, $yf3) = (0, 0, 0, 0);
	# $f11 == $f02 because of the construction
	my ($f00, $f01, $f02, $f03, $f12, $f13, $f22, $f23, $f33) =
		(0, 0, 0, 0, 0, 0, 0, 0, 0);

	for (my $i = 0; $i < $n; $i++) {
		my ($xi, $yi) = ($$x[$i], $$y[$i]);

		my $f2 = $xi * $xi;
		my $f3 = $xi * log($xi);

		$yf0 += $yi;
		$yf1 += $yi * $xi;
		$yf2 += $yi * $f2;
		$yf3 += $yi * $f3;

		$f00 += 1;
		$f01 += $xi;
		$f02 += $f2;
		$f03 += $f3;
		$f12 += $xi * $f2;
		$f13 += $xi * $f3;
		$f22 += $f2 * $f2;
		$f23 += $f2 * $f3;
		$f33 += $f3 * $f3;
	}

	my $b = [ $yf0, $yf1, $yf2, $yf3 ];
	my $M = [ [ $f00, $f01, $f02, $f03 ],
		  [ $f01, $f02, $f12, $f13 ],
		  [ $f02, $f12, $f22, $f23 ],
		  [ $f03, $f13, $f23, $f33 ]];
	solveLinearEquation($M, $b);
	# Instead of implementing Lawson & Hanson's expensive non-linear
	# Least Squares fit (which would require more linear algebra than is
	# good for a simple Perl script), we fall back to a fit without the
	# quadratic or/and linearithmic term.
	my $fit = sub ($) {
		my $x = $_[0];
		return $$b[0] + $$b[1] * $x + $$b[2] * $x * $x
			+ $$b[3] * $x * log($x);
	};

	if (is_nonnegative($b) && fit_okay($fit, $$x[$f00], $$y[$f00])) {
		return $fit;
	}
	# Try again without quadratic term
	my $b = [ $yf0, $yf1, $yf3 ];
	my $M = [ [ $f00, $f01, $f03 ],
		  [ $f01, $f02, $f13 ],
		  [ $f03, $f13, $f33 ]];
	solveLinearEquation($M, $b);
print("b: " . join(', ', @$b) . "\n");
	$fit = sub ($) {
		my $x = $_[0];
		return $$b[0] + $$b[1] * $x + $$b[2] * $x * log($x);
	};

	if (is_nonnegative($b) && fit_okay($fit, $$x[$f00], $$y[$f00])) {
		print("Warning: Least Squares Fit excluded quadratic term\n");
		return $fit;
	}
	# Try again without linearithmic term
	my $b = [ $yf0, $yf1, $yf2 ];
	my $M = [ [ $f00, $f01, $f02 ],
		  [ $f01, $f02, $f12 ],
		  [ $f02, $f12, $f22 ]];
	solveLinearEquation($M, $b);
print("b: " . join(', ', @$b) . "\n");
	$fit = sub ($) {
		my $x = $_[0];
		return $$b[0] + $$b[1] * $x + $$b[2] * $x * $x;
	};
	if (is_nonnegative($b) && fit_okay($fit, $$x[$f00], $$y[$f00])) {
		print("Warning: excluded linearithmic term\n");
		return $fit;
	}
	# Try again with simple linear regression (i.e. without quadratic and
	# without linearithmic term)
	my $b = [ $yf0, $yf1 ];
	my $M = [ [ $f00, $f01 ],
		  [ $f01, $f02 ]];
	solveLinearEquation($M, $b);
print("b: " . join(', ', @$b) . "\n");
	$fit = sub ($) {
		my $x = $_[0];
		return $$b[0] + $$b[1] * $x;
	};
	if (is_nonnegative($b) && fit_okay($fit, $$x[$f00], $$y[$f00])) {
		print("Warning: excluded quadratic & linearithmic terms\n");
		return $fit;
	}
	die("Could not find a monotonically increasing fit; bad data?");
};

die("Usage: $0 <base>") if ($#ARGV != 0);

my $base = shift(@ARGV);
my @subtests = ();
open(my $fh, '<' . $base . '.subtests');
while (<$fh>) {
	chomp();
	push(@subtests, $_);
}
close($fh);

my @sizes = ();
my @total_time = ();
my @user_time = ();
my @system_time = ();

for (my $i = 0; $i <= $#subtests; $i++) {
	open(my $fh, '<' . $base . '.' . $subtests[$i] . '.times');
	if (($_ = <$fh>) && /^(?:(\d+):)?(\d+):(\d+(?:\.\d+)?) (\d+(?:\.\d+)?) (\d+(?:\.\d+)?)$/) {
		push(@total_time, ($1 || 0) * 3600 + $2 * 60 + $3);
		push(@user_time, $4);
		push(@system_time, $5);
	}
	close($fh);
	open($fh, '<' . $base . '.' . $subtests[$i] . '.descr');
	if (($_ = <$fh>) && (/n=(\d+)/ || /(\d+)/)) {
		push(@sizes, $1);
	}
}

my $extrapolate_total = extrapolate(\@ARGV, \@total_time);
#my $extrapolate_user = extrapolate(\@ARGV, \@user_time);
#my $extrapolate_system = extrapolate(\@ARGV, \@system_time);

my $target_count = 8000;
print("Extrapolated for $target_count: " . $extrapolate_total->($target_count)
	. "\n");
print(join(", ", @sizes) . " -> " . join(", ", map { $extrapolate_total->($_) } @sizes) . "\n");
