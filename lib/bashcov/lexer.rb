module Bashcov
  # Simple lexer which analyzes Bash files in order to get information for
  # coverage
  class Lexer
    # Lines starting with one of these tokens are irrelevant for coverage
    IGNORE_START_WITH = %w(# function)

    # Lines ending with one of these tokens are irrelevant for coverage
    IGNORE_END_WITH = %w|(|

    # Lines containing only one of these keywords are irrelevant for coverage
    IGNORE_IS = %w(esac if then else elif fi while do done { } ;;)

    # @param [String] filename File to analyze
    # @param [Hash] coverage Coverage with executed lines marked
    # @raise [ArgumentError] if the given +filename+ is invalid.
    def initialize(filename, coverage)
      @filename = File.expand_path(filename)
      @coverage = coverage
      @in_case = false
      @found_case_expression = false

      raise ArgumentError, "#{@filename} is not a file" unless File.file?(@filename)
    end

    # Yields uncovered relevant lines.
    # @note Uses +@coverage+ to avoid wasting time parsing executed lines.
    # @return [void]
    def uncovered_relevant_lines
      lineno = 0
      File.open(@filename, "rb").each_line do |line|
        check_case_expression(line)
        if @coverage[lineno] == Bashcov::Line::IGNORED && revelant?(line)
          yield lineno
        end
        lineno += 1
      end
    end

  private

    def check_case_expression(line)
      if line =~ /\Acase.*/
        @in_case = true
      elsif is_case_expression?(line)
        @found_case_expression = true
      elsif @found_case_expression and line.strip.end_with? ';;'
        @found_case_expression = false
      elsif line =~ /\Aesac\z/
        @in_case = false
      end
    end

    def is_case_expression?(line)
      @in_case and !@found_case_expression and line.strip.end_with? ')'
    end

    def revelant?(line)
      line.strip!

      !line.empty? and
        !IGNORE_IS.include? line and
        !line.start_with?(*IGNORE_START_WITH) and
        !line.end_with?(*IGNORE_END_WITH) and
        line !~ /\A\w+\(\)/ and  # function declared without the 'function' keyword
        !@found_case_expression  # lines in a case statement ending with ')'
    end
  end
end
