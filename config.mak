# "RUNTIME_PREFIX" is a Windows-only feature that allows Git to probe
# for its runtime path relative to its base path.
#
# Our Git patch (see resources) extends this support to Linux and Mac.
#
# These variables configure Git to enable and use relative runtime
# paths.
RUNTIME_PREFIX = YesPlease
RUNTIME_PREFIX_PERL = YesPlease
gitexecdir = libexec/git-core
template_dir = share/git-core/templates
sysconfdir = etc
