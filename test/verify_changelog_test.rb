# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

class VerifyChangelogTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SCRIPT = File.join(ROOT, "bin", "verify_changelog")
  FIXTURES = File.join("test", "fixtures")

  def test_valid_changelog_passes
    output, status = verify("valid.md")

    assert_equal "", output
    assert_equal 0, status.exitstatus
  end

  def test_wrong_order_fails
    output, status = verify("wrong_order.md")

    assert_equal <<~OUTPUT, output
      #{path("wrong_order.md")}:6: [Enhancement] entry must come before the [Fix] entry on line 5
      #{path("wrong_order.md")}:8: [Feature] entry must come before the [Fix] entry on line 7
    OUTPUT
    assert_equal 1, status.exitstatus
  end

  def test_synonyms_fail_with_the_main_tag
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

  def test_test_only_entries_fail_with_a_hint_to_remove_them
    output, status = verify("test_only.md")

    assert_equal <<~OUTPUT, output
      #{path("test_only.md")}:4: tag [Testing] is not allowed; test-only changes get no entry, remove this line
      #{path("test_only.md")}:5: tag [Specs] is not allowed; test-only changes get no entry, remove this line
    OUTPUT
    assert_equal 1, status.exitstatus
  end

  def test_unknown_tag_fails
    output, status = verify("unknown_tag.md")

    assert_equal <<~OUTPUT, output
      #{path("unknown_tag.md")}:5: unknown tag [Security]; use one of #{all_tags}
      #{path("unknown_tag.md")}:6: tag [fix] must be written [Fix]
    OUTPUT
    assert_equal 1, status.exitstatus
  end

  def test_untagged_entry_fails
    output, status = verify("untagged.md")

    assert_equal <<~OUTPUT, output
      #{path("untagged.md")}:5: entry has no tag; start it with one of #{all_tags}
      #{path("untagged.md")}:6: entry has no tag; start it with one of #{all_tags}
    OUTPUT
    assert_equal 1, status.exitstatus
  end

  def test_bold_tags_are_the_same_as_plain_tags
    output, status = verify("bold.md")

    assert_equal <<~OUTPUT, output
      #{path("bold.md")}:8: [Feature] entry must come before the [Fix] entry on line 7
    OUTPUT
    assert_equal 1, status.exitstatus
  end

  def test_patch_is_allowed_in_rdkafka_repos
    %w[karafka/rdkafka-ruby karafka/karafka-rdkafka karafka-rdkafka].each do |repo|
      output, status = verify("patch.md", "--repo", repo)

      assert_equal "", output, repo
      assert_equal 0, status.exitstatus, repo
    end
  end

  def test_patch_repo_is_read_from_github_repository
    output, status = verify("patch.md", env: {"GITHUB_REPOSITORY" => "karafka/rdkafka-ruby"})

    assert_equal "", output
    assert_equal 0, status.exitstatus
  end

  def test_patch_fails_in_other_repos
    [["--repo", "karafka/karafka"], []].each do |args|
      output, status = verify("patch.md", *args)

      assert_equal <<~OUTPUT, output, args.inspect
        #{path("patch.md")}:5: tag [Patch] is allowed only in rdkafka-ruby and karafka-rdkafka
      OUTPUT
      assert_equal 1, status.exitstatus
    end
  end

  def test_repo_option_wins_over_github_repository
    output, status = verify(
      "patch.md",
      "--repo", "karafka/waterdrop",
      env: {"GITHUB_REPOSITORY" => "karafka/rdkafka-ruby"}
    )

    assert_match(/tag \[Patch\] is allowed only/, output)
    assert_equal 1, status.exitstatus
  end

  def test_without_unreleased_block_the_topmost_block_is_checked
    output, status = verify("no_unreleased.md")

    assert_equal <<~OUTPUT, output
      #{path("no_unreleased.md")}:5: [Feature] entry must come before the [Fix] entry on line 4
    OUTPUT
    assert_equal 1, status.exitstatus
  end

  def test_released_blocks_are_ignored
    output, status = verify("released_ignored.md")

    assert_equal "", output
    assert_equal 0, status.exitstatus
  end

  def test_changelog_without_version_block_fails
    output, status = verify("no_version.md")

    assert_equal "#{path("no_version.md")}:1: no version block (## heading) found\n", output
    assert_equal 1, status.exitstatus
  end

  def test_missing_file_fails
    output, status = verify("missing.md")

    assert_equal "#{path("missing.md")}: file not found\n", output
    assert_equal 1, status.exitstatus
  end

  def test_path_defaults_to_changelog_md
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "CHANGELOG.md"), "## Unreleased\n- [Feature] Add `#new`.\n- Untagged.\n")

      output, status = Open3.capture2e(clean_env, RbConfig.ruby, SCRIPT, chdir: dir)

      assert_equal "CHANGELOG.md:3: entry has no tag; start it with one of #{all_tags}\n", output
      assert_equal 1, status.exitstatus
    end
  end

  private

  def verify(fixture, *args, env: {})
    Open3.capture2e(clean_env.merge(env), RbConfig.ruby, SCRIPT, *args, path(fixture), chdir: ROOT)
  end

  def path(fixture)
    File.join(FIXTURES, fixture)
  end

  def clean_env
    {"GITHUB_REPOSITORY" => nil}
  end

  def all_tags
    "[Breaking] [EOL] [Feature] [Enhancement] [Change] [Refactor] [Maintenance] [Patch] [Fix]"
  end
end
