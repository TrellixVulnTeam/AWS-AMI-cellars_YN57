class Subversion < Formula
  desc "Version control system designed to be a better CVS"
  homepage "https://subversion.apache.org/"
  url "https://www.apache.org/dyn/closer.cgi?path=subversion/subversion-1.9.6.tar.bz2"
  mirror "https://archive.apache.org/dist/subversion/subversion-1.9.6.tar.bz2"
  sha256 "dbcbc51fb634082f009121f2cb64350ce32146612787ffb0f7ced351aacaae19"

  deprecated_option "java" => "with-java"
  deprecated_option "perl" => "with-perl"
  deprecated_option "ruby" => "with-ruby"

  option "with-java", "Build Java bindings"
  option "without-ruby", "Build without Ruby bindings"
  option "without-perl", "Build without Perl bindings"
  option "with-gpg-agent", "Build with support for GPG Agent"

  depends_on "pkg-config" => :build
  depends_on "apr-util"
  depends_on "apr"

  # Always build against Homebrew versions instead of system versions for consistency.
  depends_on "sqlite"
  depends_on :python => :optional
  depends_on :perl => ["5.6", :recommended]

  # Bindings require swig
  if build.with?("perl") || build.with?("python") || build.with?("ruby")
    depends_on "swig" => :build
  end

  # For Serf
  depends_on "scons" => :build
  depends_on "openssl"

  unless OS.mac?
    depends_on "expat"
    depends_on "libmagic"
    depends_on "zlib"
    depends_on "krb5" => :recommended
    depends_on "util-linux" # for libuuid
    depends_on :ruby => ["1.8", :recommended]
  end

  # Other optional dependencies
  depends_on "gpg-agent" => :optional
  depends_on :java => :optional

  resource "serf" do
    url "https://www.apache.org/dyn/closer.cgi?path=serf/serf-1.3.9.tar.bz2"
    mirror "https://archive.apache.org/dist/serf/serf-1.3.9.tar.bz2"
    sha256 "549c2d21c577a8a9c0450facb5cca809f26591f048e466552240947bdf7a87cc"
  end

  # Fix #23993 by stripping flags swig can't handle from SWIG_CPPFLAGS
  # Prevent "-arch ppc" from being pulled in from Perl's $Config{ccflags}
  # Prevent linking into a Python Framework
  patch :DATA

  if build.with?("perl") || build.with?("ruby")
    # When building Perl or Ruby bindings, need to use a compiler that
    # recognizes GCC-style switches, since that's what the system languages
    # were compiled against.
    fails_with :clang do
      build 318
      cause "core.c:1: error: bad value (native) for -march= switch"
    end
  end

  def install
    serf_prefix = OS.mac? ? libexec/"serf" : prefix

    resource("serf").stage do
      inreplace "SConstruct" do |s|
        s.gsub! "env.Append(LIBPATH=['$OPENSSL\/lib'])",
        "\\1\nenv.Append(CPPPATH=['$ZLIB\/include'])\nenv.Append(LIBPATH=['$ZLIB/lib'])"
      end unless OS.mac?

      # scons ignores our compiler and flags unless explicitly passed
      args = %W[
        PREFIX=#{serf_prefix} GSSAPI=#{Formula["krb5"].opt_prefix} CC=#{ENV.cc}
        CFLAGS=#{ENV.cflags} LINKFLAGS=#{ENV.ldflags} 
        OPENSSL=#{Formula["openssl"].opt_prefix}
        APR=#{Formula["apr"].opt_prefix}
        APU=#{Formula["apr-util"].opt_prefix}
        ZLIB=#{Formula["zlib"].opt_prefix}
      ]
      scons(*args)
      scons "install"
    end

    if build.with? "java"
      # Java support doesn't build correctly in parallel:
      # https://github.com/Homebrew/homebrew/issues/20415
      ENV.deparallelize
    end

    # Use existing system zlib
    # Use dep-provided other libraries
    # Don't mess with Apache modules (since we're not sudo)
    args = %W[
      --prefix=#{prefix}
      --disable-debug
      --enable-optimize
      --with-zlib=#{OS.mac? ? "/usr" : Formula["zlib"].opt_prefix}
      --with-sqlite=#{Formula["sqlite"].opt_prefix}
      --with-apr=#{Formula["apr"].opt_prefix}
      --with-apr-util=#{Formula["apr-util"].opt_prefix}
      --with-apxs=no
      --with-serf=#{serf_prefix}
      --disable-mod-activation
      --disable-nls
      --without-apache-libexecdir
      --without-berkeley-db
    ]

    args << "--enable-javahl" << "--without-jikes" if build.with? "java"
    args << "--without-gpg-agent" if build.without? "gpg-agent"

    if build.with? "ruby"
      args << "--with-ruby-sitedir=#{lib}/ruby"
      # Peg to system Ruby
      args << "RUBY=/usr/bin/ruby" if OS.mac?
    end

    # The system Python is built with llvm-gcc, so we override this
    # variable to prevent failures due to incompatible CFLAGS
    ENV["ac_cv_python_compile"] = ENV.cc

    inreplace "Makefile.in",
              "toolsdir = @bindir@/svn-tools",
              "toolsdir = @libexecdir@/svn-tools"

    system "./configure", *args
    system "make"
    # Fix ld: cannot find -lsvn_delta-1
    ENV.deparallelize { system "make", "install" }
    bash_completion.install "tools/client-side/bash_completion" => "subversion"

    system "make", "tools"
    system "make", "install-tools"

    if build.with? "python"
      system "make", "swig-py"
      system "make", "install-swig-py"
      odie
      (lib/"python2.7/site-packages").install_symlink Dir["#{lib}/svn-python/*"]
    end

    if build.with? "perl"
      # In theory SWIG can be built in parallel, in practice...
      ENV.deparallelize

      archlib = Utils.popen_read("perl -MConfig -e 'print $Config{archlib}'")
      perl_core = Pathname.new(archlib)/"CORE"
      onoe "'#{perl_core}' does not exist" unless perl_core.exist?

      inreplace "Makefile" do |s|
        s.change_make_var! "SWIG_PL_INCLUDES",
          "$(SWIG_INCLUDES) #{"-arch #{MacOS.preferred_arch}" if OS.mac?} -g -pipe -fno-common #{"-DPERL_DARWIN" if OS.mac?} -fno-strict-aliasing -I#{HOMEBREW_PREFIX}/include -I#{perl_core}"
      end
      system "make", "swig-pl"
      system "make", "install-swig-pl"

      # This is only created when building against system Perl, but it isn't
      # purged by Homebrew's post-install cleaner because that doesn't check
      # "Library" directories. It is however pointless to keep around as it
      # only contains the perllocal.pod installation file.
      rm_rf prefix/"Library/Perl"
    end

    if build.with? "java"
      system "make", "javahl"
      system "make", "install-javahl"
    end

    if build.with? "ruby"
      # Peg to system Ruby
      system "make", "swig-rb", "EXTRA_SWIG_LDFLAGS=-L/usr/lib"
      system "make", "install-swig-rb"
    end
  end

  def caveats
    s = <<-EOS.undent
      svntools have been installed to:
        #{opt_libexec}
    EOS

    if build.with? "perl"
      s += <<-EOS.undent

        The perl bindings are located in various subdirectories of:
          #{opt_lib}/perl5
      EOS
    end

    if build.with? "ruby"
      s += <<-EOS.undent

        If you wish to use the Ruby bindings you may need to add:
          #{HOMEBREW_PREFIX}/lib/ruby
        to your RUBYLIB.
      EOS
    end

    if build.with? "java"
      s += <<-EOS.undent

        You may need to link the Java bindings into the Java Extensions folder:
          sudo mkdir -p /Library/Java/Extensions
          sudo ln -s #{HOMEBREW_PREFIX}/lib/libsvnjavahl-1.dylib /Library/Java/Extensions/libsvnjavahl-1.dylib
      EOS
    end

    s
  end

  test do
    system "#{bin}/svnadmin", "create", "test"
    system "#{bin}/svnadmin", "verify", "test"
  end
end

__END__
diff --git a/configure b/configure
index 445251b..6ff4332 100755
--- a/configure
+++ b/configure
@@ -26153,6 +26153,8 @@ fi
 SWIG_CPPFLAGS="$CPPFLAGS"
 
   SWIG_CPPFLAGS=`echo "$SWIG_CPPFLAGS" | $SED -e 's/-no-cpp-precomp //'`
+  SWIG_CPPFLAGS=`echo "$SWIG_CPPFLAGS" | $SED -e 's/-F\/[^ ]* //'`
+  SWIG_CPPFLAGS=`echo "$SWIG_CPPFLAGS" | $SED -e 's/-isystem\/[^ ]* //'`
 
 
   SWIG_CPPFLAGS=`echo "$SWIG_CPPFLAGS" | $SED -e 's/-Wdate-time //'`
diff --git a/subversion/bindings/swig/perl/native/Makefile.PL.in b/subversion/bindings/swig/perl/native/Makefile.PL.in
index a60430b..bd9b017 100644
--- a/subversion/bindings/swig/perl/native/Makefile.PL.in
+++ b/subversion/bindings/swig/perl/native/Makefile.PL.in
@@ -76,10 +76,13 @@ my $apr_ldflags = '@SVN_APR_LIBS@'
 
 chomp $apr_shlib_path_var;
 
+my $config_ccflags = $Config{ccflags};
+$config_ccflags =~ s/-arch\s+\S+//g;
+
 my %config = (
     ABSTRACT => 'Perl bindings for Subversion',
     DEFINE => $cppflags,
-    CCFLAGS => join(' ', $cflags, $Config{ccflags}),
+    CCFLAGS => join(' ', $cflags, $config_ccflags),
     INC  => join(' ', $includes, $cppflags,
                  " -I$swig_srcdir/perl/libsvn_swig_perl",
                  " -I$svnlib_srcdir/include",

diff --git a/build/get-py-info.py b/build/get-py-info.py
index 29a6c0a..dd1a5a8 100644
--- a/build/get-py-info.py
+++ b/build/get-py-info.py
@@ -83,7 +83,7 @@ def link_options():
   options = sysconfig.get_config_var('LDSHARED').split()
   fwdir = sysconfig.get_config_var('PYTHONFRAMEWORKDIR')

-  if fwdir and fwdir != "no-framework":
+  if fwdir and fwdir != "no-framework" and sys.platform != 'darwin':

     # Setup the framework prefix
     fwprefix = sysconfig.get_config_var('PYTHONFRAMEWORKPREFIX')
