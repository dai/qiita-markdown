require "active_support/core_ext/string/strip"

describe Qiita::Markdown::Processor do
  describe "#call" do
    subject do
      result[:output].to_s
    end

    let(:context) do
      {}
    end

    let(:markdown) do
      raise NotImplementedError
    end

    let(:result) do
      described_class.new(context).call(markdown)
    end

    context "with valid condition" do
      let(:markdown) do
        <<-EOS.strip_heredoc
          example
        EOS
      end

      it "returns a Hash with HTML output and other metadata" do
        expect(result[:codes]).to be_an Array
        expect(result[:mentioned_usernames]).to be_an Array
        expect(result[:output]).to be_a Nokogiri::HTML::DocumentFragment
      end
    end

    context "with HTML-characters" do
      let(:markdown) do
        "<>&"
      end

      it "sanitizes them" do
        should eq <<-EOS.strip_heredoc
          <p>&lt;&gt;&amp;</p>
        EOS
      end
    end

    context "with headings" do
      let(:markdown) do
        <<-EOS.strip_heredoc
          # a
          ## a
          ### a
          ### a
        EOS
      end

      it "adds ID for ToC" do
        should eq <<-EOS.strip_heredoc
          <h1>
          <span id="a" class="fragment"></span><a href="#a"><i class="fa fa-link"></i></a>a</h1>

          <h2>
          <span id="a-1" class="fragment"></span><a href="#a-1"><i class="fa fa-link"></i></a>a</h2>

          <h3>
          <span id="a-2" class="fragment"></span><a href="#a-2"><i class="fa fa-link"></i></a>a</h3>

          <h3>
          <span id="a-3" class="fragment"></span><a href="#a-3"><i class="fa fa-link"></i></a>a</h3>
        EOS
      end
    end

    context "with code" do
      let(:markdown) do
        <<-EOS.strip_heredoc
          ```foo.rb
          puts 'hello world'
          ```
        EOS
      end

      it "returns detected codes" do
        expect(result[:codes]).to eq [
          {
            code: "puts 'hello world'\n",
            filename: "foo.rb",
            language: "ruby",
          },
        ]
      end
    end

    context 'with code & filename' do
      let(:markdown) do
        <<-EOS.strip_heredoc
          ```example.rb
          1
          ```
        EOS
      end

      it 'returns code-frame, code-lang, and highlighted pre element' do
        should eq <<-EOS.strip_heredoc
          <div class="code-frame" data-lang="ruby">
          <div class="code-lang"><span class="bold">example.rb</span></div>
          <div class="highlight"><pre><span class="mi">1</span>
          </pre></div>
          </div>
        EOS
      end

    end

    context 'with code & no filename' do
      let(:markdown) do
        <<-EOS.strip_heredoc
          ```ruby
          1
          ```
        EOS
      end

      it 'returns code-frame and highlighted pre element' do
        should eq <<-EOS.strip_heredoc
          <div class="code-frame" data-lang="ruby"><div class="highlight"><pre><span class="mi">1</span>
          </pre></div></div>
        EOS
      end
    end

    context "with undefined but aliased language" do
      let(:markdown) do
        <<-EOS.strip_heredoc
          ```zsh
          true
          ```
        EOS
      end

      it "returns aliased language name" do
        expect(result[:codes]).to eq [
          {
            code: "true\n",
            filename: nil,
            language: "bash",
          },
        ]
      end
    end

    context "with script element" do
      let(:markdown) do
        <<-EOS.strip_heredoc
          <script>alert(1)</script>
        EOS
      end

      it "removes script element" do
        should eq "<p></p>\n"
      end
    end

    context "with script context" do
      before do
        context[:script] = true
      end

      let(:markdown) do
        <<-EOS.strip_heredoc
          <p><script>alert(1)</script></p>
        EOS
      end

      it "allows script element" do
        should eq markdown
      end
    end

    context "with data-attribute" do
      before do
        context[:script] = true
      end

      let(:markdown) do
        <<-EOS.strip_heredoc
          <p><script async data-a="b">alert(1)</script></p>
        EOS
      end

      it "allows data-attributes" do
        should eq markdown
      end
    end

    context "with iframe" do
      before do
        context[:script] = true
      end

      let(:markdown) do
        <<-EOS.strip_heredoc
          <iframe width="1" height="2" src="//example.com" frameborder="0" allowfullscreen></iframe>
        EOS
      end

      it "allows iframe with some attributes" do
        should eq markdown
      end
    end

    context "with mention" do
      let(:markdown) do
        "@alice"
      end

      it "replaces mention with link" do
        should include(<<-EOS.strip_heredoc.rstrip)
          <a href="/alice" class="user-mention" title="alice">@alice</a>
        EOS
      end
    end

    context "with mentions in complex patterns" do
      let(:markdown) do
        <<-EOS.strip_heredoc
          @alice

          ```
            @bob
          ```

          @charlie/@dave
          @ell_en
          @fran-k
          @Isaac
          @justin
          @justin
          @mallory@github
          @#{?o * 33}
          @oo
        EOS
      end

      it "extracts mentions correctly" do
        expect(result[:mentioned_usernames]).to eq %W[
          alice
          dave
          ell_en
          fran-k
          Isaac
          justin
          mallory@github
        ]
      end
    end

    context "with allowed_usernames context" do
      before do
        context[:allowed_usernames] = ["alice"]
      end

      let(:markdown) do
        <<-EOS.strip_heredoc
          @alice
          @bob
        EOS
      end

      it "limits mentions to allowed usernames" do
        expect(result[:mentioned_usernames]).to eq ["alice"]
      end
    end

    context "with normal link" do
      let(:markdown) do
        "[](/example)"
      end

      it "creates link for that" do
        should eq <<-EOS.strip_heredoc
          <p><a href="/example"></a></p>
        EOS
      end
    end

    context "with anchor link" do
      let(:markdown) do
        "[](#example)"
      end

      it "creates link for that" do
        should eq <<-EOS.strip_heredoc
          <p><a href="#example"></a></p>
        EOS
      end
    end

    context "with javascript: link" do
      let(:markdown) do
        "[](javascript:alert(1))"
      end

      it "removes that link by creating empty a element" do
        should eq <<-EOS.strip_heredoc
          <p><a></a></p>
        EOS
      end
    end

    context "with mailto: link" do
      let(:markdown) do
        "[](mailto:info@example.com)"
      end

      it "removes that link by creating empty a element" do
        should eq <<-EOS.strip_heredoc
          <p><a></a></p>
        EOS
      end
    end

    context "with emoji" do
      let(:markdown) do
        ":+1:"
      end

      it "replaces it with img element" do
        should include('img')
      end
    end

    context "with emoji in pre or code element" do
      let(:markdown) do
        <<-EOS.strip_heredoc
          ```
          :+1:
          ```
        EOS
      end

      it "does not replace it" do
        should_not include('img')
      end
    end

    context "with colon-only label" do
      let(:markdown) do
        <<-EOS.strip_heredoc
          ```:
          1
          ```
        EOS
      end

      it "does not replace it" do
        expect(result[:codes]).to eq [
          {
            code: "1\n",
            filename: nil,
            language: nil,
          },
        ]
      end
    end

    context "with font element with color attribute" do
      let(:markdown) do
        %[<font color="red">test</font>]
      end

      it "allows font element with color attribute" do
        should eq <<-EOS.strip_heredoc
          <p>#{markdown}</p>
        EOS
      end
    end

    context "with checkbox list" do
      let(:markdown) do
        <<-EOS.strip_heredoc
          - [ ] a
          - [x] b
        EOS
      end

      it "inserts checkbox" do
        should eq <<-EOS.strip_heredoc
          <ul>
          <li class="task-list-item">
          <input type="checkbox" class="task-list-item-checkbox" data-checkbox-index="0">a</li>
          <li class="task-list-item">
          <input type="checkbox" class="task-list-item-checkbox" data-checkbox-index="1" checked>b</li>
          </ul>
        EOS
      end
    end

    context "with nested checkbox list" do
      let(:markdown) do
        <<-EOS.strip_heredoc
          - [ ] a
           - [ ] b
        EOS
      end

      it "inserts checkbox" do
        should eq <<-EOS.strip_heredoc
          <ul>
          <li class="task-list-item">
          <input type="checkbox" class="task-list-item-checkbox" data-checkbox-index="0">a

          <ul>
          <li class="task-list-item">
          <input type="checkbox" class="task-list-item-checkbox" data-checkbox-index="1">b</li>
          </ul>
          </li>
          </ul>
        EOS
      end
    end

    context 'with checkbox list in code block' do
      let(:markdown) do
        <<-EOS.strip_heredoc
          ```
          - [ ] a
          - [x] b
          ```
        EOS
      end

      it "does not replace checkbox" do
        should eq <<-EOS.strip_heredoc
          <div class="code-frame" data-lang="text"><div class="highlight"><pre>- [ ] a
          - [x] b
          </pre></div></div>
        EOS
      end
    end

    context "with checkbox list and :checkbox_disabled context" do
      before do
        context[:checkbox_disabled] = true
      end

      let(:markdown) do
        <<-EOS.strip_heredoc
          - [ ] a
          - [x] b
        EOS
      end

      it "inserts checkbox with disabled attribute" do
        should eq <<-EOS.strip_heredoc
          <ul>
          <li class="task-list-item">
          <input type="checkbox" class="task-list-item-checkbox" data-checkbox-index="0" disabled>a</li>
          <li class="task-list-item">
          <input type="checkbox" class="task-list-item-checkbox" data-checkbox-index="1" checked disabled>b</li>
          </ul>
        EOS
      end
    end
  end
end
