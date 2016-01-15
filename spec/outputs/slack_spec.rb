require_relative "../spec_helper"

describe LogStash::Outputs::Slack do

  # Actually do most of the boiler plate by stubbing out the request, running
  # the logstash pipeline, and asserting that a request was made with the
  # expected JSON.
  def test_one_event(logstash_config, expected_json)
    stub_request(:post, "requestb.in").
      to_return(:body => "", :status => 200,
                :headers => { 'Content-Length' => 0 })

    LogStash::Pipeline.new(logstash_config).run

    expect(a_request(:post, "http://requestb.in/r9lkbzr9").
           with(:body => "payload=#{CGI.escape(JSON.dump(expected_json))}",
                :headers => {
                  'Content-Type' => 'application/x-www-form-urlencoded',
                  'Accept'=> 'application/json',
                  'User-Agent' => 'logstash-output-slack'
                  })).
           to have_been_made.once
  end

  before do
    WebMock.disable_net_connect!
  end

  after do
    WebMock.reset!
    WebMock.allow_net_connect!
  end

  context "passes the right payload to slack and" do
    it "uses all default values" do
      expected_json = {
        :text => "This message should show in slack"
      }
      logstash_config = <<-CONFIG
          input {
            generator {
              message => "This message should show in slack"
              count => 1
            }
          }
          output {
            slack {
              url => "http://requestb.in/r9lkbzr9"
            }
          }
      CONFIG

      test_one_event(logstash_config, expected_json)
    end

    it "uses and formats all provided values" do
      expected_json = {
        :text => "This message should show in slack 3",
        :channel => "mychannel",
        :username => "slackbot",
        :icon_emoji => ":chart_with_upwards_trend:",
        :icon_url => "http://lorempixel.com/48/48"
      }

      logstash_config = <<-CONFIG
          input {
            generator {
              message => "This message should show in slack"
              add_field => {"x" => "3"
                            "channelname" => "mychannel"
                            "username" => "slackbot"}
              count => 1
            }
          }
          output {
            slack {
              url => "http://requestb.in/r9lkbzr9"
              format => "%{message} %{x}"
              channel => "%{channelname}"
              username => "%{username}"
              icon_emoji => ":chart_with_upwards_trend:"
              icon_url => "http://lorempixel.com/48/48"
            }
          }
      CONFIG

      test_one_event(logstash_config, expected_json)
    end

    it "uses and formats all provided values" do
      expected_json = {
        :text => "Unformatted message",
        :channel => "mychannel",
        :username => "slackbot",
        :icon_emoji => ":chart_with_upwards_trend:",
        :icon_url => "http://lorempixel.com/48/48"
      }

      logstash_config = <<-CONFIG
          input {
            generator {
              message => "This message should show in slack"
              count => 1
            }
          }
          output {
            slack {
              url => "http://requestb.in/r9lkbzr9"
              format => "Unformatted message"
              channel => "mychannel"
              username => "slackbot"
              icon_emoji => ":chart_with_upwards_trend:"
              icon_url => "http://lorempixel.com/48/48"
            }
          }
      CONFIG

      test_one_event(logstash_config, expected_json)
    end

    it "uses the default attachments if none are in the event" do
      expected_json = {
        :text => "This message should show in slack",
        :attachments => [{:image_url => "http://example.com/image.png"}]
      }

      logstash_config = <<-CONFIG
          input {
            generator {
              message => "This message should show in slack"
              count => 1
            }
          }
          output {
            slack {
              url => "http://requestb.in/r9lkbzr9"
              attachments => [
                {image_url => "http://example.com/image.png"}
              ]
            }
          }
      CONFIG

      test_one_event(logstash_config, expected_json)
    end

    it "supports multiple default attachments" do
      expected_json = {
        :text => "This message should show in slack",
        :attachments => [{:image_url => "http://example.com/image1.png"},
                         {:image_url => "http://example.com/image2.png"}]
      }

      logstash_config = <<-CONFIG
          input {
            generator {
              message => "This message should show in slack"
              count => 1
            }
          }
          output {
            slack {
              url => "http://requestb.in/r9lkbzr9"
              attachments => [
                {image_url => "http://example.com/image1.png"},
                {image_url => "http://example.com/image2.png"}
              ]
            }
          }
      CONFIG

      test_one_event(logstash_config, expected_json)
    end

    it "ignores empty default attachments" do
      expected_json = {
        :text => "This message should show in slack"
      }

      logstash_config = <<-CONFIG
          input {
            generator {
              message => "This message should show in slack"
              count => 1
            }
          }
          output {
            slack {
              url => "http://requestb.in/r9lkbzr9"
              attachments => []
            }
          }
      CONFIG

      test_one_event(logstash_config, expected_json)
    end

    it "uses event attachments over default attachments" do
      expected_json = {
        :text => "This message should show in slack",
        :attachments => [{:thumb_url => "http://other.com/thumb.png"}]
      }

      # add_field only takes string values, so we'll have to mutate to JSON
      logstash_config = <<-CONFIG
          input {
            generator {
              message => "This message should show in slack"
              count => 1
              add_field => {
                attachments => '[{"thumb_url": "http://other.com/thumb.png"}]'
              }
            }
          }
          filter {
            json {
              source => "attachments"
              target => "attachments"
            }
          }
          output {
            slack {
              url => "http://requestb.in/r9lkbzr9"
              attachments => [
                {image_url => "http://example.com/image1.png"},
                {image_url => "http://example.com/image2.png"}
              ]
            }
          }
      CONFIG

      test_one_event(logstash_config, expected_json)
    end

    it "erases default attachments if event attachments empty" do
      expected_json = {
        :text => "This message should show in slack"
      }

      # add_field only takes string values, so we'll have to mutate to JSON
      logstash_config = <<-CONFIG
          input {
            generator {
              message => "This message should show in slack"
              count => 1
              add_field => {attachments => '[]'}
            }
          }
          filter {
            json {
              source => "attachments"
              target => "attachments"
            }
          }
          output {
            slack {
              url => "http://requestb.in/r9lkbzr9"
              attachments => [
                {image_url => "http://example.com/image1.png"},
                {image_url => "http://example.com/image2.png"}
              ]
            }
          }
      CONFIG

      test_one_event(logstash_config, expected_json)
    end

    it "ignores event attachment if not array" do
      expected_json = {
        :text => "This message should show in slack",
        :attachments => [{:image_url => "http://example.com/image.png"}]
      }

      logstash_config = <<-CONFIG
          input {
            generator {
              message => "This message should show in slack"
              count => 1
              add_field => {attachments => "baddata"}
            }
          }
          output {
            slack {
              url => "http://requestb.in/r9lkbzr9"
              attachments => [
                {image_url => "http://example.com/image.png"}
              ]
            }
          }
      CONFIG

      test_one_event(logstash_config, expected_json)
    end
    
    it  "supports disabling link expansion option" do
      expected_json = {
        :text => "This message should show in slack",
        :unfurl_links => true
      }
      
      logstash_config = <<-CONFIG
          input {
            generator {
              message => "This message should show in slack"
              count => 1
            }
          }
          output {
            slack {
              url => "http://requestb.in/r9lkbzr9"
              options => {
                'auto_expand_links' => true
              }
            }
          }
      CONFIG

      test_one_event(logstash_config, expected_json)
    end

    it  "supports disabling media expansion option" do
      expected_json = {
        :text => "This message should show in slack",
        :unfurl_media => false
      }
      
      logstash_config = <<-CONFIG
          input {
            generator {
              message => "This message should show in slack"
              count => 1
            }
          }
          output {
            slack {
              url => "http://requestb.in/r9lkbzr9"
              options => {
                'auto_expand_media' => false
              }
            }
          }
      CONFIG

      test_one_event(logstash_config, expected_json)
    end

    it  "uses automatic fallback for disabling expansion option" do
       #  for any non-boolean value in the options.auto_expand_(media|links) should fallbacks to false
      expected_json = {
        :text => "This message should show in slack",
        :unfurl_links => false
        :unfurl_media => false
      }
      
      logstash_config = <<-CONFIG
          input {
            generator {
              message => "This message should show in slack"
              count => 1
            }
          }
          output {
            slack {
              url => "http://requestb.in/r9lkbzr9"
              options => {
                'auto_expand_media' => "non boolean value"
                'auto_expand_links' => "just another invalid value"
              }
            }
          }
      CONFIG

      test_one_event(logstash_config, expected_json)
    end

  end
end
