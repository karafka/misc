# frozen_string_literal: true

require "minitest/autorun"
require "minitest/spec"
require "open3"
require "rbconfig"
require "tmpdir"

describe "bin/verify_changelog" do
  it "expect a valid changelog to pass" do
    output, status = verify("valid.md")

    assert_equal "", output
    assert_equal 0, status.exitstatus
  end

  it "expect entries in the wrong order to fail" do
    output, status = verify("wrong_order.md")

    assert_equal <<~OUTPUT, output
      #{path("wrong_order.md")}:6: [Enhancement] entry must come before the [Fix] entry on line 5
      #{path("wrong_order.md")}:8: [Feature] entry must come before the [Fix] entry on line 7
    OUTPUT
    assert_equal 1, status.exitstatus
  end

  it "expect synonyms to fail with the main tag" do
    output, status = verify("synonym.md")

    assert_equal <<~OUTPUT, output
      #{path("synonym.md")}:4: tag [Breaking change] is not allowed; use [Breaking]
      #{path("synonym.md")}:5: tag [Improvement] is not allowed; use [Enhancement]
      #{path("synonym.md")}:6: tag [Deprecation] is not allowed; use [Change]
      #{path("synonym.md")}:7: tag [Deprecated] is not allowed; use [Change]
      #{path("synonym.md")}:8: tag [Refactoring] is not allowed; use [Refactor]
    OUTPUT
    assert_equal 1, status.exitstatus
  end

  it "expect test-only entries to fail with a hint to remove them" do
    output, status = verify("test_only.md")

    assert_equal <<~OUTPUT, output
      #{path("test_only.md")}:4: tag [Testing] is not allowed; test-only changes get no entry, remove this line
      #{path("test_only.md")}:5: tag [Specs] is not allowed; test-only changes get no entry, remove this line
    OUTPUT
    assert_equal 1, status.exitstatus
  end

  it "expect an unknown tag to fail" do
    output, status = verify("unknown_tag.md")

    assert_equal <<~OUTPUT, output
      #{path("unknown_tag.md")}:5: unknown tag [Security]; use one of #{all_tags}
      #{path("unknown_tag.md")}:6: tag [fix] must be written [Fix]
    OUTPUT
    assert_equal 1, status.exitstatus
  end

  it "expect an untagged entry to fail" do
    output, status = verify("untagged.md")

    assert_equal <<~OUTPUT, output
      #{path("untagged.md")}:5: entry has no tag; start it with one of #{all_tags}
      #{path("untagged.md")}:6: entry has no tag; start it with one of #{all_tags}
    OUTPUT
    assert_equal 1, status.exitstatus
  end

  it "expect bold tags to be the same as plain tags" do
    output, status = verify("bold.md")

    assert_equal <<~OUTPUT, output
      #{path("bold.md")}:8: [Feature] entry must come before the [Fix] entry on line 7
    OUTPUT
    assert_equal 1, status.exitstatus
  end

  it "expect [Patch] to be allowed in the rdkafka repos" do
    %w[karafka/rdkafka-ruby karafka/karafka-rdkafka karafka-rdkafka].each do |repo|
      output, status = verify("patch.md", "--repo", repo)

      assert_equal "", output, repo
      assert_equal 0, status.exitstatus, repo
    end
  end

  it "expect the repo to be read from GITHUB_REPOSITORY" do
    output, status = verify("patch.md", env: {"GITHUB_REPOSITORY" => "karafka/rdkafka-ruby"})

    assert_equal "", output
    assert_equal 0, status.exitstatus
  end

  it "expect [Patch] to fail in other repos" do
    [["--repo", "karafka/karafka"], []].each do |args|
      output, status = verify("patch.md", *args)

      assert_equal <<~OUTPUT, output, args.inspect
        #{path("patch.md")}:5: tag [Patch] is allowed only in rdkafka-ruby and karafka-rdkafka
      OUTPUT
      assert_equal 1, status.exitstatus
    end
  end

  it "expect --repo to win over GITHUB_REPOSITORY" do
    output, status = verify(
      "patch.md",
      "--repo", "karafka/waterdrop",
      env: {"GITHUB_REPOSITORY" => "karafka/rdkafka-ruby"}
    )

    assert_match(/tag \[Patch\] is allowed only/, output)
    assert_equal 1, status.exitstatus
  end

  it "expect the topmost block to be checked when there is no Unreleased block" do
    output, status = verify("no_unreleased.md")

    assert_equal <<~OUTPUT, output
      #{path("no_unreleased.md")}:5: [Feature] entry must come before the [Fix] entry on line 4
    OUTPUT
    assert_equal 1, status.exitstatus
  end

  it "expect released blocks to be ignored" do
    output, status = verify("released_ignored.md")

    assert_equal "", output
    assert_equal 0, status.exitstatus
  end

  it "expect an (Unreleased) block below a released block to be checked" do
    output, status = verify("unreleased_below_released.md")

    assert_equal <<~OUTPUT, output
      #{path("unreleased_below_released.md")}:8: [Feature] entry must come before the [Fix] entry on line 7
    OUTPUT
    assert_equal 1, status.exitstatus
  end

  it "expect an ## Unreleased block below a released block to be checked" do
    output, status = verify("plain_unreleased_below_released.md")

    assert_equal <<~OUTPUT, output
      #{path("plain_unreleased_below_released.md")}:8: [Feature] entry must come before the [Fix] entry on line 7
    OUTPUT
    assert_equal 1, status.exitstatus
  end

  it "expect a second Unreleased block to fail" do
    output, status = verify("two_unreleased.md")

    assert_equal <<~OUTPUT, output
      #{path("two_unreleased.md")}:6: second Unreleased block; move its entries into the one on line 3
    OUTPUT
    assert_equal 1, status.exitstatus
  end

  it "expect a UTF-8 changelog to pass with a non-UTF-8 locale" do
    output, status = verify("utf8.md", env: {"LANG" => "C", "LC_ALL" => "C"})

    assert_equal "", output
    assert_equal 0, status.exitstatus
  end

  it "expect invalid UTF-8 to fail" do
    output, status = verify("invalid_utf8.md", env: {"LANG" => "C", "LC_ALL" => "C"})

    assert_equal "#{path("invalid_utf8.md")}:4: invalid UTF-8\n", output
    assert_equal 1, status.exitstatus
  end

  it "expect an unknown option to fail with the usage line" do
    output, status = verify("valid.md", "--bogus")

    assert_equal "invalid option: --bogus\n#{usage}\n", output
    assert_equal 1, status.exitstatus
  end

  it "expect --repo without a value to fail with the usage line" do
    output, status = Open3.capture2e(clean_env, RbConfig.ruby, script, "--repo", chdir: root)

    assert_equal "missing argument: --repo\n#{usage}\n", output
    assert_equal 1, status.exitstatus
  end

  it "expect more than one path to fail with the usage line" do
    output, status = verify("valid.md", path("untagged.md"))

    assert_equal "only one PATH is allowed\n#{usage}\n", output
    assert_equal 1, status.exitstatus
  end

  it "expect a changelog without a version block to fail" do
    output, status = verify("no_version.md")

    assert_equal "#{path("no_version.md")}:1: no version block (## heading) found\n", output
    assert_equal 1, status.exitstatus
  end

  it "expect a missing file to fail" do
    output, status = verify("missing.md")

    assert_equal "#{path("missing.md")}: file not found\n", output
    assert_equal 1, status.exitstatus
  end

  it "expect the path to default to CHANGELOG.md" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "CHANGELOG.md"), "## Unreleased\n- [Feature] Add `#new`.\n- Untagged.\n")

      output, status = Open3.capture2e(clean_env, RbConfig.ruby, script, chdir: dir)

      assert_equal "CHANGELOG.md:3: entry has no tag; start it with one of #{all_tags}\n", output
      assert_equal 1, status.exitstatus
    end
  end

  def root
    File.expand_path("..", __dir__)
  end

  def script
    File.join(root, "bin", "verify_changelog")
  end

  def verify(fixture, *args, env: {})
    Open3.capture2e(clean_env.merge(env), RbConfig.ruby, script, *args, path(fixture), chdir: root)
  end

  def path(fixture)
    File.join("test", "fixtures", fixture)
  end

  def clean_env
    {"GITHUB_REPOSITORY" => nil}
  end

  def usage
    "Usage: bin/verify_changelog [--repo NAME] [PATH]"
  end

  def all_tags
    "[Breaking] [EOL] [Feature] [Enhancement] [Change] [Refactor] [Maintenance] [Patch] [Fix]"
  end
end
