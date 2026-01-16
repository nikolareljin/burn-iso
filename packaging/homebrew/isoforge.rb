class Isoforge < Formula
  desc "TUI tool for downloading and flashing ISO images to USB"
  homepage "https://github.com/nikolareljin/burn-iso"
  url "https://github.com/nikolareljin/burn-iso/releases/download/v1.0.0/isoforge-1.0.0.tar.gz"
  version "1.0.0"
  sha256 "346e8d52d2f7b2394ae7dcd962518e2736232f04c8c25e6bd3d8df94ca45bfa9"
  license "MIT"

  depends_on "dialog"
  depends_on "jq"
  depends_on "curl"

  def install
    libexec.install Dir["*"]
    (bin/"isoforge").write <<~EOS
      #!/bin/bash
      export ISOFORGE_ROOT="#{libexec}"
      exec "#{libexec}/inc/isoforge.sh" "$@"
    EOS
    man1.install "#{libexec}/docs/man/isoforge.1"
  end
end
