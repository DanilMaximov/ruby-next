# source: https://github.com/ruby/spec/blob/master/language/pattern_matching_spec.rb

# NOTE: the following changes to the original code should be made:
# - Add `using RubyNext::Language::Eval`
# - Remove expected messages from SyntaxError
# - Skip warnings specs
# - Move `using refinery` inside `eval`

require_relative '../spec_helper'

using RubyNext::Language::Eval

ruby_version_is "2.7" do
  describe "Pattern matching" do
    # TODO: Remove excessive eval calls when support of previous version
    #       Ruby 2.6 will be dropped

    before :each do
      ScratchPad.record []
    end

    ruby_version_is "3.0" do
      it "can be standalone assoc operator that deconstructs value" do
        suppress_warning do
          eval(<<-RUBY).should == [0, 1]
            [0, 1] => [a, b]
            [a, b]
          RUBY
        end
      end

      describe "find pattern" do
        it "captures preceding elements to the pattern" do
          eval(<<~RUBY).should == [0, 1]
            case [0, 1, 2, 3]
            in [*pre, 2, 3]
              pre
            else
              false
            end
          RUBY
        end

        it "captures following elements to the pattern" do
          eval(<<~RUBY).should == [2, 3]
            case [0, 1, 2, 3]
            in [0, 1, *post]
              post
            else
              false
            end
          RUBY
        end

        it "captures both preceding and following elements to the pattern" do
          eval(<<~RUBY).should == [[0, 1], [3, 4]]
            case [0, 1, 2, 3, 4]
            in [*pre, 2, *post]
              [pre, post]
            else
              false
            end
          RUBY
        end

        it "can capture the entirety of the pattern" do
          eval(<<~RUBY).should == [0, 1, 2, 3, 4]
            case [0, 1, 2, 3, 4]
            in [*everything]
              everything
            else
              false
            end
          RUBY
        end

        it "will match an empty Array-like structure" do
          eval(<<~RUBY).should == []
            case []
            in [*everything]
              everything
            else
              false
            end
          RUBY
        end

        it "can be nested" do
          eval(<<~RUBY).should == [[0, [2, 4, 6]], [[4, 16, 64]], 27]
            case [0, [2, 4, 6], [3, 9, 27], [4, 16, 64]]
            in [*pre, [*, 9, a], *post]
              [pre, post, a]
            else
              false
            end
          RUBY
        end

        it "can be nested with an array pattern" do
          eval(<<~RUBY).should == [[4, 16, 64]]
            case [0, [2, 4, 6], [3, 9, 27], [4, 16, 64]]
            in [_, _, [*, 9, *], *post]
              post
            else
              false
            end
          RUBY
        end

        it "can be nested within a hash pattern" do
          eval(<<~RUBY).should == [27]
            case {a: [3, 9, 27]}
            in {a: [*, 9, *post]}
              post
            else
              false
            end
          RUBY
        end

        it "can nest hash and array patterns" do
          eval(<<~RUBY).should == [42, 2]
            case [0, {a: 42, b: [0, 1]}, {a: 42, b: [1, 2]}]
            in [*, {a:, b: [1, c]}, *]
              [a, c]
            else
              false
            end
          RUBY
        end
      end
    end

    it "extends case expression with case/in construction" do
      eval(<<~RUBY).should == :bar
        case [0, 1]
        in [0]
          :foo
        in [0, 1]
          :bar
        end
      RUBY
    end

    it "allows using then operator" do
      eval(<<~RUBY).should == :bar
        case [0, 1]
        in [0]    then :foo
        in [0, 1] then :bar
        end
      RUBY
    end

    it "binds variables" do
      eval(<<~RUBY).should == 1
        case [0, 1]
        in [0, a]
          a
        end
      RUBY
    end

    it "cannot mix in and when operators" do
      -> {
        eval <<~RUBY
          case []
          when 1 == 1
          in []
          end
        RUBY
      }.should raise_error(SyntaxError)

      -> {
        eval <<~RUBY
          case []
          in []
          when 1 == 1
          end
        RUBY
      }.should raise_error(SyntaxError)
    end

    it "checks patterns until the first matching" do
      eval(<<~RUBY).should == :bar
        case [0, 1]
        in [0]
          :foo
        in [0, 1]
          :bar
        in [0, 1]
          :baz
        end
      RUBY
    end

    it "executes else clause if no pattern matches" do
      eval(<<~RUBY).should == false
        case [0, 1]
        in [0]
          true
        else
          false
        end
      RUBY
    end

    it "raises NoMatchingPatternError if no pattern matches and no else clause" do
      -> {
        eval <<~RUBY
          case [0, 1]
          in [0]
          end
        RUBY
      }.should raise_error(NoMatchingPatternError, /\[0, 1\]/)
    end

    it "does not allow calculation or method calls in a pattern" do
      -> {
        eval <<~RUBY
          case 0
          in 1 + 1
            true
          end
        RUBY
      }.should raise_error(SyntaxError, /unexpected/)
    end

    it "evaluates the case expression once for multiple patterns, caching the result" do
      eval(<<~RUBY).should == true
        case (ScratchPad << :foo; 1)
        in 0
          false
        in 1
          true
        end
      RUBY

      ScratchPad.recorded.should == [:foo]
    end

    describe "guards" do
      it "supports if guard" do
        eval(<<~RUBY).should == false
          case 0
          in 0 if false
            true
          else
            false
          end
        RUBY

        eval(<<~RUBY).should == true
          case 0
          in 0 if true
            true
          else
            false
          end
        RUBY
      end

      it "supports unless guard" do
        eval(<<~RUBY).should == false
          case 0
          in 0 unless true
            true
          else
            false
          end
        RUBY

        eval(<<~RUBY).should == true
          case 0
          in 0 unless false
            true
          else
            false
          end
        RUBY
      end

      it "makes bound variables visible in guard" do
        eval(<<~RUBY).should == true
          case [0, 1]
          in [a, 1] if a >= 0
            true
          end
        RUBY
      end

      it "does not evaluate guard if pattern does not match" do
        eval <<~RUBY
          case 0
          in 1 if (ScratchPad << :foo) || true
          else
          end
        RUBY

        ScratchPad.recorded.should == []
      end

      it "takes guards into account when there are several matching patterns" do
        eval(<<~RUBY).should == :bar
          case 0
          in 0 if false
            :foo
          in 0 if true
            :bar
          end
        RUBY
      end

      it "executes else clause if no guarded pattern matches" do
        eval(<<~RUBY).should == false
          case 0
          in 0 if false
            true
          else
            false
          end
        RUBY
      end

      it "raises NoMatchingPatternError if no guarded pattern matches and no else clause" do
        -> {
          eval <<~RUBY
            case [0, 1]
            in [0, 1] if false
            end
          RUBY
        }.should raise_error(NoMatchingPatternError, /\[0, 1\]/)
      end
    end

    describe "value pattern" do
      it "matches an object such that pattern === object" do
        eval(<<~RUBY).should == true
          case 0
          in 0
            true
          end
        RUBY

        eval(<<~RUBY).should == true
          case 0
          in (-1..1)
            true
          end
        RUBY

        eval(<<~RUBY).should == true
          case 0
          in Integer
            true
          end
        RUBY

        eval(<<~RUBY).should == true
          case "0"
          in /0/
            true
          end
        RUBY

        eval(<<~RUBY).should == true
          case "0"
          in ->(s) { s == "0" }
            true
          end
        RUBY
      end

      it "allows string literal with interpolation" do
        x = "x"

        eval(<<~RUBY).should == true
          case "x"
          in "#{x + ""}"
            true
          end
        RUBY
      end
    end

    describe "variable pattern" do
      it "matches a value and binds variable name to this value" do
        eval(<<~RUBY).should == 0
          case 0
          in a
            a
          end
        RUBY
      end

      it "makes bounded variable visible outside a case statement scope" do
        eval(<<~RUBY).should == 0
          case 0
          in a
          end

          a
        RUBY
      end

      it "create local variables even if a pattern doesn't match" do
        eval(<<~RUBY).should == [0, nil, nil]
          case 0
          in a
          in b
          in c
          end

          [a, b, c]
        RUBY
      end

      it "allow using _ name to drop values" do
        eval(<<~RUBY).should == 0
          case [0, 1]
          in [a, _]
            a
          end
        RUBY
      end

      it "supports using _ in a pattern several times" do
        eval(<<~RUBY).should == true
          case [0, 1, 2]
          in [0, _, _]
            true
          end
        RUBY
      end

      it "supports using any name with _ at the beginning in a pattern several times" do
        eval(<<~RUBY).should == true
          case [0, 1, 2]
          in [0, _x, _x]
            true
          end
        RUBY

        eval(<<~RUBY).should == true
          case {a: 0, b: 1, c: 2}
          in {a: 0, b: _x, c: _x}
            true
          end
        RUBY
      end

      it "does not support using variable name (except _) several times" do
        -> {
          eval <<~RUBY
            case [0]
            in [a, a]
            end
          RUBY
        }.should raise_error(SyntaxError)
      end

      it "supports existing variables in a pattern specified with ^ operator" do
        eval(<<~RUBY).should == true
          a = 0

          case 0
          in ^a
            true
          end
        RUBY
      end

      it "allows applying ^ operator to bound variables" do
        eval(<<~RUBY).should == 1
          case [1, 1]
          in [n, ^n]
            n
          end
        RUBY

        eval(<<~RUBY).should == false
          case [1, 2]
          in [n, ^n]
            true
          else
            false
          end
        RUBY
      end

      it "requires bound variable to be specified in a pattern before ^ operator when it relies on a bound variable" do
        -> {
          eval <<~RUBY
            case [1, 2]
            in [^n, n]
              true
            else
              false
            end
          RUBY
        }.should raise_error(SyntaxError)
      end
    end

    describe "alternative pattern" do
      it "matches if any of patterns matches" do
        eval(<<~RUBY).should == true
          case 0
          in 0 | 1 | 2
            true
          end
        RUBY
      end

      it "does not support variable binding" do
        -> {
          eval <<~RUBY
            case [0, 1]
            in [0, 0] | [0, a]
            end
          RUBY
        }.should raise_error(SyntaxError, /illegal variable in alternative pattern/)
      end

      it "support underscore prefixed variables in alternation" do
        eval(<<~RUBY).should == true
          case [0, 1]
          in [1, _]
            false
          in [0, 0] | [0, _a]
            true
          end
        RUBY
      end

      it "can be used as a nested pattern" do
        eval(<<~RUBY).should == true
          case [[1], ["2"]]
            in [[0] | nil, _]
              false
            in [[1], [1]]
              false
            in [[1], [2 | "2"]]
              true
          end
        RUBY

        eval(<<~RUBY).should == true
          case [1, 2]
            in [0, _] | {a: 0}
              false
            in {a: 1, b: 2} | [1, 2]
              true
          end
        RUBY
      end
    end

    describe "AS pattern" do
      it "binds a variable to a value if pattern matches" do
        eval(<<~RUBY).should == 0
          case 0
          in Integer => n
            n
          end
        RUBY
      end

      it "can be used as a nested pattern" do
        eval(<<~RUBY).should == [2, 3]
          case [1, [2, 3]]
          in [1, Array => ary]
            ary
          end
        RUBY
      end
    end

    describe "Array pattern" do
      it "supports form Constant(pat, pat, ...)" do
        eval(<<~RUBY).should == true
          case [0, 1, 2]
          in Array(0, 1, 2)
            true
          end
        RUBY
      end

      it "supports form Constant[pat, pat, ...]" do
        eval(<<~RUBY).should == true
          case [0, 1, 2]
          in Array[0, 1, 2]
            true
          end
        RUBY
      end

      it "supports form [pat, pat, ...]" do
        eval(<<~RUBY).should == true
          case [0, 1, 2]
          in [0, 1, 2]
            true
          end
        RUBY
      end

      it "supports form pat, pat, ..." do
        eval(<<~RUBY).should == true
          case [0, 1, 2]
          in 0, 1, 2
            true
          end
        RUBY

        eval(<<~RUBY).should == 1
          case [0, 1, 2]
          in 0, a, 2
            a
          end
        RUBY

        eval(<<~RUBY).should == [1, 2]
          case [0, 1, 2]
          in 0, *rest
            rest
          end
        RUBY
      end

      it "matches an object with #deconstruct method which returns an array and each element in array matches element in pattern" do
        obj = Object.new
        def obj.deconstruct; [0, 1] end

        eval(<<~RUBY).should == true
          case obj
          in [Integer, Integer]
            true
          end
        RUBY
      end

      ruby_version_is "3.0" do
        it "calls #deconstruct once for multiple patterns, caching the result" do
          # 2.7 doesn't cache
          next skip if RUBY_VERSION =~ /^2\.7\./

          obj = Object.new

          def obj.deconstruct
            ScratchPad << :deconstruct
            [0, 1]
          end

          eval(<<~RUBY).should == true
            case obj
            in [1, 2]
              false
            in [0, 1]
              true
            end
          RUBY

          ScratchPad.recorded.should == [:deconstruct]
        end
      end

      it "calls #deconstruct even on objects that are already an array" do
        obj = [1, 2]
        def obj.deconstruct
          ScratchPad << :deconstruct
          [3, 4]
        end

        eval(<<~RUBY).should == true
          case obj
          in [3, 4]
            true
          else
            false
          end
        RUBY

        ScratchPad.recorded.should == [:deconstruct]
      end

      it "does not match object if Constant === object returns false" do
        eval(<<~RUBY).should == false
          case [0, 1, 2]
          in String[0, 1, 2]
            true
          else
            false
          end
        RUBY
      end

      it "does not match object without #deconstruct method" do
        obj = Object.new
        obj.should_receive(:respond_to?).with(:deconstruct)

        eval(<<~RUBY).should == false
          case obj
          in Object[]
            true
          else
            false
          end
        RUBY
      end

      it "raises TypeError if #deconstruct method does not return array" do
        obj = Object.new
        def obj.deconstruct; "" end

        -> {
          eval <<~RUBY
            case obj
            in Object[]
            else
            end
          RUBY
        }.should raise_error(TypeError, /deconstruct must return Array/)
      end

      it "accepts a subclass of Array from #deconstruct" do
        obj = Object.new
        def obj.deconstruct
          subarray = Class.new(Array).new(2)
          def subarray.[](n)
            n
          end
          subarray
        end

        eval(<<~RUBY).should == true
          case obj
          in [1, 2]
            false
          in [0, 1]
            true
          end
        RUBY
      end

      it "does not match object if elements of array returned by #deconstruct method does not match elements in pattern" do
        obj = Object.new
        def obj.deconstruct; [1] end

        eval(<<~RUBY).should == false
          case obj
          in Object[0]
            true
          else
            false
          end
        RUBY
      end

      it "binds variables" do
        eval(<<~RUBY).should == [0, 1, 2]
          case [0, 1, 2]
          in [a, b, c]
            [a, b, c]
          end
        RUBY
      end

      it "supports splat operator *rest" do
        eval(<<~RUBY).should == [1, 2]
          case [0, 1, 2]
          in [0, *rest]
            rest
          end
        RUBY
      end

      it "does not match partially by default" do
        eval(<<~RUBY).should == false
          case [0, 1, 2, 3]
          in [1, 2]
            true
          else
            false
          end
        RUBY
      end

      it "does match partially from the array beginning if list + , syntax used" do
        eval(<<~RUBY).should == true
          case [0, 1, 2, 3]
          in [0, 1,]
            true
          end
        RUBY

        eval(<<~RUBY).should == true
          case [0, 1, 2, 3]
          in 0, 1,;
            true
          end
        RUBY
      end

      it "matches [] with []" do
        eval(<<~RUBY).should == true
          case []
          in []
            true
          end
        RUBY
      end

      it "matches anything with *" do
        eval(<<~RUBY).should == true
          case [0, 1]
          in *;
            true
          end
        RUBY
      end

      it "can be used as a nested pattern" do
        eval(<<~RUBY).should == true
          case [[1], ["2"]]
            in [[0] | nil, _]
              false
            in [[1], [1]]
              false
            in [[1], [2 | "2"]]
              true
          end
        RUBY

        eval(<<~RUBY).should == true
          case [1, 2]
            in [0, _] | {a: 0}
              false
            in {a: 1, b: 2} | [1, 2]
              true
          end
        RUBY
      end
    end

    describe "Hash pattern" do
      it "supports form Constant(id: pat, id: pat, ...)" do
        eval(<<~RUBY).should == true
          case {a: 0, b: 1}
          in Hash(a: 0, b: 1)
            true
          end
        RUBY
      end

      it "supports form Constant[id: pat, id: pat, ...]" do
        eval(<<~RUBY).should == true
          case {a: 0, b: 1}
          in Hash[a: 0, b: 1]
            true
          end
        RUBY
      end

      it "supports form {id: pat, id: pat, ...}" do
        eval(<<~RUBY).should == true
          case {a: 0, b: 1}
          in {a: 0, b: 1}
            true
          end
        RUBY
      end

      it "supports form id: pat, id: pat, ..." do
        eval(<<~RUBY).should == true
          case {a: 0, b: 1}
          in a: 0, b: 1
            true
          end
        RUBY

        eval(<<~RUBY).should == [0, 1]
          case {a: 0, b: 1}
          in a: a, b: b
            [a, b]
          end
        RUBY

        eval(<<~RUBY).should == { b: 1, c: 2 }
          case {a: 0, b: 1, c: 2}
          in a: 0, **rest
            rest
          end
        RUBY
      end

      it "supports a: which means a: a" do
        eval(<<~RUBY).should == [0, 1]
          case {a: 0, b: 1}
          in Hash(a:, b:)
            [a, b]
          end
        RUBY

        a = b = nil
        eval(<<~RUBY).should == [0, 1]
          case {a: 0, b: 1}
          in Hash[a:, b:]
            [a, b]
          end
        RUBY

        a = b = nil
        eval(<<~RUBY).should == [0, 1]
          case {a: 0, b: 1}
          in {a:, b:}
            [a, b]
          end
        RUBY

        a = nil
        eval(<<~RUBY).should == [0, {b: 1, c: 2}]
          case {a: 0, b: 1, c: 2}
          in {a:, **rest}
            [a, rest]
          end
        RUBY

        a = b = nil
        eval(<<~RUBY).should == [0, 1]
          case {a: 0, b: 1}
          in a:, b:
            [a, b]
          end
        RUBY
      end

      it "can mix key (a:) and key-value (a: b) declarations" do
        eval(<<~RUBY).should == [0, 1]
          case {a: 0, b: 1}
          in Hash(a:, b: x)
            [a, x]
          end
        RUBY
      end

      it "supports 'string': key literal" do
        eval(<<~RUBY).should == true
          case {a: 0}
          in {"a": 0}
            true
          end
        RUBY
      end

      it "does not support non-symbol keys" do
        -> {
          eval <<~RUBY
            case {a: 1}
            in {"a" => 1}
            end
          RUBY
        }.should raise_error(SyntaxError, /unexpected/)
      end

      it "does not support string interpolation in keys" do
        x = "a"

        -> {
          eval <<~'RUBY'
            case {a: 1}
            in {"#{x}": 1}
            end
          RUBY
        }.should raise_error(SyntaxError, /symbol literal with interpolation is not allowed/)
      end

      it "raise SyntaxError when keys duplicate in pattern" do
        -> {
          eval <<~RUBY
            case {a: 1}
            in {a: 1, b: 2, a: 3}
            end
          RUBY
        }.should raise_error(SyntaxError)
      end

      it "matches an object with #deconstruct_keys method which returns a Hash with equal keys and each value in Hash matches value in pattern" do
        obj = Object.new
        def obj.deconstruct_keys(*); {a: 1} end

        eval(<<~RUBY).should == true
          case obj
          in {a: 1}
            true
          end
        RUBY
      end

      it "calls #deconstruct_keys per pattern" do
        obj = Object.new

        def obj.deconstruct_keys(*)
          ScratchPad << :deconstruct_keys
          {a: 1}
        end

        eval(<<~RUBY).should == true
          case obj
          in {b: 1}
            false
          in {a: 1}
            true
          end
        RUBY

        ScratchPad.recorded.should == [:deconstruct_keys, :deconstruct_keys]
      end

      it "does not match object if Constant === object returns false" do
        eval(<<~RUBY).should == false
          case {a: 1}
          in String[a: 1]
            true
          else
            false
          end
        RUBY
      end

      it "does not match object without #deconstruct_keys method" do
        obj = Object.new
        obj.should_receive(:respond_to?).with(:deconstruct_keys)

        eval(<<~RUBY).should == false
          case obj
          in Object[a: 1]
            true
          else
            false
          end
        RUBY
      end

      it "does not match object if #deconstruct_keys method does not return Hash" do
        obj = Object.new
        def obj.deconstruct_keys(*); "" end

        -> {
          eval <<~RUBY
            case obj
            in Object[a: 1]
            end
          RUBY
        }.should raise_error(TypeError, /deconstruct_keys must return Hash/)
      end

      it "does not match object if #deconstruct_keys method returns Hash with non-symbol keys" do
        obj = Object.new
        def obj.deconstruct_keys(*); {"a" => 1} end

        eval(<<~RUBY).should == false
          case obj
          in Object[a: 1]
            true
          else
            false
          end
        RUBY
      end

      it "does not match object if elements of Hash returned by #deconstruct_keys method does not match values in pattern" do
        obj = Object.new
        def obj.deconstruct_keys(*); {a: 1} end

        eval(<<~RUBY).should == false
          case obj
          in Object[a: 2]
            true
          else
            false
          end
        RUBY
      end

      it "passes keys specified in pattern as arguments to #deconstruct_keys method" do
        obj = Object.new

        def obj.deconstruct_keys(*args)
          ScratchPad << args
          {a: 1, b: 2, c: 3}
        end

        eval <<~RUBY
          case obj
          in Object[a: 1, b: 2, c: 3]
          end
        RUBY

        ScratchPad.recorded.sort.should == [[[:a, :b, :c]]]
      end

      it "passes keys specified in pattern to #deconstruct_keys method if pattern contains double splat operator **" do
        obj = Object.new

        def obj.deconstruct_keys(*args)
          ScratchPad << args
          {a: 1, b: 2, c: 3}
        end

        eval <<~RUBY
          case obj
          in Object[a: 1, b: 2, **]
          end
        RUBY

        ScratchPad.recorded.sort.should == [[[:a, :b]]]
      end

      it "passes nil to #deconstruct_keys method if pattern contains double splat operator **rest" do
        obj = Object.new

        def obj.deconstruct_keys(*args)
          ScratchPad << args
          {a: 1, b: 2}
        end

        eval <<~RUBY
          case obj
          in Object[a: 1, **rest]
          end
        RUBY

        ScratchPad.recorded.should == [[nil]]
      end

      it "binds variables" do
        eval(<<~RUBY).should == [0, 1, 2]
          case {a: 0, b: 1, c: 2}
          in {a: x, b: y, c: z}
            [x, y, z]
          end
        RUBY
      end

      it "supports double splat operator **rest" do
        eval(<<~RUBY).should == {b: 1, c: 2}
          case {a: 0, b: 1, c: 2}
          in {a: 0, **rest}
            rest
          end
        RUBY
      end

      it "treats **nil like there should not be any other keys in a matched Hash" do
        eval(<<~RUBY).should == true
          case {a: 1, b: 2}
          in {a: 1, b: 2, **nil}
            true
          end
        RUBY

        eval(<<~RUBY).should == false
          case {a: 1, b: 2}
          in {a: 1, **nil}
            true
          else
            false
          end
        RUBY
      end

      it "can match partially" do
        eval(<<~RUBY).should == true
          case {a: 1, b: 2}
          in {a: 1}
            true
          end
        RUBY
      end

      it "matches {} with {}" do
        eval(<<~RUBY).should == true
          case {}
          in {}
            true
          end
        RUBY
      end

      it "matches anything with **" do
        eval(<<~RUBY).should == true
          case {a: 1}
          in **;
            true
          end
        RUBY
      end

      it "can be used as a nested pattern" do
        eval(<<~RUBY).should == true
          case {a: {a: 1, b: 1}, b: {a: 1, b: 2}}
            in {a: {a: 0}}
              false
            in {a: {a: 1}, b: {b: 1}}
              false
            in {a: {a: 1}, b: {b: 2}}
              true
          end
        RUBY

        eval(<<~RUBY).should == true
          case [{a: 1, b: [1]}, {a: 1, c: ["2"]}]
            in [{a:, c:},]
              false
            in [{a: 1, b:}, {a: 1, c: [Integer]}]
              false
            in [_, {a: 1, c: [String]}]
              true
          end
        RUBY
      end
    end

    describe "refinements" do
      it "are used for #deconstruct" do
        refinery = Module.new do
          refine Array do
            def deconstruct
              [0]
            end
          end
        end

        result = nil
        Module.new do
          result = eval(<<~RUBY)
            using refinery

            case []
            in [0]
              true
            end
          RUBY
        end

        result.should == true
      end

      it "are used for #deconstruct_keys" do
        refinery = Module.new do
          refine Hash do
            def deconstruct_keys(_)
              {a: 0}
            end
          end
        end

        result = nil
        Module.new do
          result = eval(<<~RUBY)
            using refinery

            case {}
            in a: 0
              true
            end
          RUBY
        end

        result.should == true
      end

      it "are used for #=== in constant pattern" do
        refinery = Module.new do
          refine Array.singleton_class do
            def ===(obj)
              obj.is_a?(Hash)
            end
          end
        end

        result = nil
        Module.new do
          result = eval(<<~RUBY)
            using refinery

            case {}
            in Array
              true
            end
          RUBY
        end

        result.should == true
      end
    end

    describe "Constant" do
      it "supports form Constant[id: { arr: [...] }] => var)" do
        eval(<<~RUBY).should == true
          var = [
            {
              contents: {
                parts: [1, 2, 3]
              }
            }
          ]
          case var
          in Array[
            {
              contents: Hash[
                parts: Array[_, _, *] => arr
                ] => hash
            }
          ]
            arr == [1, 2, 3] && hash[:parts].size == 3
          end
        RUBY
      end
    end

    ruby_version_is "3.1" do
      it "can omit parentheses in one line pattern matching" do
        eval(<<~RUBY).should == [1, 2]
          [1, 2] => a, b
          [a, b]
        RUBY

        eval(<<~RUBY).should == 1
          {a: 1} => a:
          a
        RUBY
      end

      it "supports pinning instance variables" do
        eval(<<~RUBY).should == true
          @a = /a/
          case 'abc'
          in ^@a
            true
          end
        RUBY
      end

      it "supports pinning class variables" do
        result = nil
        Module.new do
          result = module_eval(<<~RUBY)
            @@a = 0..10

            case 2
            in ^@@a
              true
            end
          RUBY
        end

        result.should == true
      end

      it "supports pinning global variables" do
        eval(<<~RUBY).should == true
          $a = /a/
          case 'abc'
          in ^$a
            true
          end
        RUBY
      end

      it "supports pinning expressions" do
        eval(<<~RUBY).should == true
          case 'abc'
            in ^(/a/)
            true
          end
        RUBY

        eval(<<~RUBY).should == true
          case {name: '2.6', released_at: Time.new(2018, 12, 25)}
            in {released_at: ^(Time.new(2010)..Time.new(2020))}
            true
          end
        RUBY

        eval(<<~RUBY).should == true
          case 0
          in ^(0+0)
            true
          end
        RUBY
      end
    end

    if RubyNext.proposed_syntax?
      ruby_version_is "next" do
        it "supports binding instance variables" do
          eval(<<~RUBY).should == true
            case %w[a b c]
            in [@a, @b, *]
              true
            end
          RUBY

          @a.should == 'a'
          @b.should == 'b'

          eval(<<~RUBY)
            %w[foo bar] => @a, @b
          RUBY

          @a.should == 'foo'
          @b.should == 'bar'

          eval(<<~RUBY)
            42 in Integer => @a
          RUBY

          @a.should == 42
        end

        it "supports binding class variables" do
          result = nil
          Module.new do
            result = module_eval(<<~RUBY)
              @@a = 0
              case 2
              in @@a
                true
              end

              @@a
            RUBY
          end

          result.should == 2
        end

        it "supports binding global variables" do
          eval(<<~RUBY).should == true
            $a = 0
            case Hash[a: 1, b: 2022]
            in {a: $a, **$b}
              true
            end
          RUBY

          $a.should == 1
          $b.should == {b: 2022}

          eval(<<~RUBY)
            42 => $a
          RUBY

          $a.should == 42
        end

        it "doesn't support non-local variable binding in alternation pattern" do
          -> {
            eval <<~RUBY
              case 0
              in 0 | @a
              end
            RUBY
          }.should raise_error(SyntaxError, /illegal variable in alternative pattern/)

          -> {
            Module.new do
              module_eval(<<~RUBY)
                case 0
                in 0 | @@a
                end
              RUBY
            end
          }.should raise_error(SyntaxError, /illegal variable in alternative pattern/)

          -> {
            eval <<~RUBY
              case 0
              in 0 | $a
              end
            RUBY
          }.should raise_error(SyntaxError, /illegal variable in alternative pattern/)
        end
      end
    end
  end
end
