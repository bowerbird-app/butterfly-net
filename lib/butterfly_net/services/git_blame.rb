# frozen_string_literal: true

require "shellwords"

module ButterflyNet
  module Services
    # Service to extract git blame information from backtrace lines.
    # Parses backtrace to identify file locations and retrieves
    # the author responsible for the code that caused the error.
    class GitBlame
      BlameResult = Struct.new(:file, :line_number, :commit_sha, :author_name, :author_email, :commit_date, :line_content, :context_lines, keyword_init: true)

      BACKTRACE_LINE_REGEX = /^(.+):(\d+):in/.freeze

      attr_reader :repo_path

      def initialize(repo_path: nil)
        @repo_path = repo_path || ButterflyNet.configuration.repo_path || default_repo_path
      end

      # Extracts blame information for the first application file in the backtrace
      # @param backtrace_lines [Array<String>] array of backtrace lines
      # @return [BlameResult, nil] blame information or nil if not found
      def blame_from_backtrace(backtrace_lines)
        return nil if backtrace_lines.blank?

        backtrace_lines.each do |line|
          result = blame_line(line)
          return result if result
        end

        nil
      end

      # Extracts blame information for all application files in the backtrace
      # @param backtrace_lines [Array<String>] array of backtrace lines
      # @return [Array<BlameResult>] array of blame results
      def blame_all_from_backtrace(backtrace_lines)
        return [] if backtrace_lines.blank?

        results = []
        backtrace_lines.each do |line|
          result = blame_line(line)
          results << result if result
        end
        results
      end

      # Extracts blame information for a single backtrace line
      # @param backtrace_line [String] a single backtrace line
      # @return [BlameResult, nil] blame information or nil if not in repo
      def blame_line(backtrace_line)
        match = backtrace_line.match(BACKTRACE_LINE_REGEX)
        return nil unless match

        file_path = match[1]
        line_number = match[2].to_i

        blame_file(file_path, line_number)
      end

      # Gets blame information for a specific file and line number
      # @param file_path [String] path to the file
      # @param line_number [Integer] line number in the file
      # @return [BlameResult, nil] blame information or nil if not available
      def blame_file(file_path, line_number)
        relative_path = relative_to_repo(file_path)
        return nil unless relative_path
        return nil unless file_in_repo?(relative_path)

        run_git_blame(relative_path, line_number)
      end

      private

      def default_repo_path
        return Rails.root.to_s if defined?(Rails) && Rails.respond_to?(:root)

        Dir.pwd
      end

      # Converts absolute path to path relative to repo
      def relative_to_repo(file_path)
        return nil if file_path.blank?

        expanded_repo = File.expand_path(repo_path)
        expanded_file = File.expand_path(file_path)

        return nil unless expanded_file.start_with?(expanded_repo)

        Pathname.new(expanded_file).relative_path_from(Pathname.new(expanded_repo)).to_s
      end

      def file_in_repo?(relative_path)
        full_path = File.join(repo_path, relative_path)
        File.exist?(full_path)
      end

      def run_git_blame(relative_path, line_number)
        Dir.chdir(repo_path) do
          # Use porcelain format for easier parsing
          output = `git blame -L #{line_number},#{line_number} --porcelain -- #{Shellwords.shellescape(relative_path)} 2>/dev/null`
          return nil unless $?.success? && output.present?

          result = parse_porcelain_output(output, relative_path, line_number)
          return nil unless result

          result.context_lines = read_surrounding_lines(relative_path, line_number)
          result
        end
      rescue StandardError => e
        Rails.logger.error("[ButterflyNet] GitBlame error: #{e.message}") if defined?(Rails)
        nil
      end

      def read_surrounding_lines(relative_path, line_number, window: 5)
        full_path = File.join(repo_path, relative_path)
        return nil unless File.exist?(full_path)

        lines = File.readlines(full_path, chomp: true)
        start_idx = [ line_number - window - 1, 0 ].max
        end_idx   = [ line_number + window - 1, lines.length - 1 ].min

        lines[start_idx..end_idx].each_with_index.map do |content, idx|
          { line_number: start_idx + idx + 1, content: content }
        end
      rescue StandardError
        nil
      end

      def parse_porcelain_output(output, file_path, line_number)
        lines = output.lines.map(&:chomp)
        return nil if lines.empty?

        # First line contains: commit_sha original_line final_line [count]
        first_line = lines[0]
        commit_sha = first_line.split.first

        author_name = nil
        author_email = nil
        commit_date = nil
        line_content = nil

        lines.each do |line|
          case line
          when /^author (.+)$/
            author_name = ::Regexp.last_match(1)
          when /^author-mail <(.+)>$/
            author_email = ::Regexp.last_match(1)
          when /^author-time (\d+)$/
            timestamp = ::Regexp.last_match(1).to_i
            commit_date = Time.at(timestamp).utc
          when /^\t(.*)$/
            line_content = ::Regexp.last_match(1)
          end
        end

        BlameResult.new(
          file: file_path,
          line_number: line_number,
          commit_sha: commit_sha,
          author_name: author_name,
          author_email: author_email,
          commit_date: commit_date,
          line_content: line_content
        )
      end
    end
  end
end
