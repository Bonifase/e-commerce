class ErlangAT19 < Formula
  desc "Programming language for highly scalable real-time systems"
  homepage "https://www.erlang.org/"
  # Download tarball from GitHub; it is served faster than the official tarball.
  url "https://github.com/erlang/otp/archive/OTP-19.3.6.10.tar.gz"
  sha256 "1185dd3f8d4b642fee25d45dfa28e1f19821a2ea6bb1a371b21d10bd72ffdff5"

  bottle do
    cellar :any
    sha256 "856388a4fddd8aa95e37219652951911d3bf651b6fb91e1c4b4d848ad7dfda03" => :mojave
    sha256 "dbd31486de44976b0037ab7dd0b15226434fa1af7cd52d842e5f05e229662c85" => :high_sierra
    sha256 "7c36b7291e17204ed15f08e23971d209b2246ce31519f995f9d190671e528103" => :sierra
    sha256 "7a642f1ba90903bc65025ffe91078227f92f0962c41cd3d3be1d6b05034d9a0f" => :el_capitan
  end

  keg_only :versioned_formula

  option "without-hipe", "Disable building hipe; fails on various macOS systems"
  option "with-native-libs", "Enable native library compilation"
  option "with-dirty-schedulers", "Enable experimental dirty schedulers"
  option "with-java", "Build jinterface application"
  option "without-docs", "Do not install documentation"

  deprecated_option "disable-hipe" => "without-hipe"
  deprecated_option "no-docs" => "without-docs"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "openssl"
  depends_on "fop" => :optional # enables building PDF docs
  depends_on :java => :optional
  depends_on "wxmac" => :recommended # for GUI apps like observer

  # Check if this patch can be removed when OTP 19.4 is released.
  # Erlang will crash on macOS 10.13 any time the crypto lib is used.
  # The Erlang team has an open PR for the patch but it needs to be applied to
  # older releases. See https://github.com/erlang/otp/pull/1501 and
  # https://bugs.erlang.org/browse/ERL-439 for additional information.
  patch do
    url "https://raw.githubusercontent.com/Homebrew/formula-patches/1f4a770/erlang%4019/boring-ssl-high-sierra.patch"
    sha256 "5aae52e7947db400a7798e8cda6e33e30088edf816e842cb09974b92c6b5eba6"
  end

  # Pointer comparison triggers error with Xcode 9
  patch do
    url "https://github.com/erlang/otp/commit/a64c4d806fa54848c35632114585ad82b98712e8.diff?full_index=1"
    sha256 "3261400f8d7f0dcff3a52821daea3391ebfa01fd859f9f2d9cc5142138e26e15"
  end

  resource "man" do
    url "https://www.erlang.org/download/otp_doc_man_19.3.tar.gz"
    mirror "https://www.mirrorservice.org/sites/ftp.netbsd.org/pub/pkgsrc/distfiles/erlang/otp_doc_man_19.3.tar.gz"
    sha256 "f8192ffdd7367083c055695eeddf198155da43dcc221aed1d870d1e3871dd95c"
  end

  resource "html" do
    url "https://www.erlang.org/download/otp_doc_html_19.3.tar.gz"
    mirror "https://www.mirrorservice.org/sites/ftp.netbsd.org/pub/pkgsrc/distfiles/erlang/otp_doc_html_19.3.tar.gz"
    sha256 "dc3e3a82d1aba7f0deac1ddb81b7d6f8dee9a75e1d42b90c677a2b645f19a00c"
  end

  def install
    # Unset these so that building wx, kernel, compiler and
    # other modules doesn't fail with an unintelligable error.
    %w[LIBS FLAGS AFLAGS ZFLAGS].each { |k| ENV.delete("ERL_#{k}") }

    ENV["FOP"] = "#{HOMEBREW_PREFIX}/bin/fop" if build.with? "fop"

    # Do this if building from a checkout to generate configure
    system "./otp_build", "autoconf" if File.exist? "otp_build"

    args = %W[
      --disable-debug
      --disable-silent-rules
      --prefix=#{prefix}
      --enable-kernel-poll
      --enable-threads
      --enable-sctp
      --enable-dynamic-ssl-lib
      --with-ssl=#{Formula["openssl"].opt_prefix}
      --enable-shared-zlib
      --enable-smp-support
    ]

    args << "--enable-darwin-64bit" if MacOS.prefer_64_bit?
    args << "--enable-native-libs" if build.with? "native-libs"
    args << "--enable-dirty-schedulers" if build.with? "dirty-schedulers"
    args << "--enable-wx" if build.with? "wxmac"
    args << "--with-dynamic-trace=dtrace" if MacOS::CLT.installed?

    if build.without? "hipe"
      # HIPE doesn't strike me as that reliable on macOS
      # https://syntatic.wordpress.com/2008/06/12/macports-erlang-bus-error-due-to-mac-os-x-1053-update/
      # https://www.erlang.org/pipermail/erlang-patches/2008-September/000293.html
      args << "--disable-hipe"
    else
      args << "--enable-hipe"
    end

    if build.with? "java"
      args << "--with-javac"
    else
      args << "--without-javac"
    end

    system "./configure", *args
    system "make"
    system "make", "install"

    if build.with? "docs"
      (lib/"erlang").install resource("man").files("man")
      doc.install resource("html")
    end
  end

  def caveats; <<~EOS
    Man pages can be found in:
      #{opt_lib}/erlang/man
    Access them with `erl -man`, or add this directory to MANPATH.
  EOS
  end

  test do
    system "#{bin}/erl", "-noshell", "-eval", "crypto:start().", "-s", "init", "stop"
  end
end