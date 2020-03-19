require 'spec_helper'

describe Test do
  let(:message) do
    "Test *tested* failed\nDb: *test2*\nDateHour: *10001*\n"
  end
  describe '#update_item' do
    let(:dynamo) { Database.new }
    let(:item) do
      dynamo.item('test2', 10001).item
    end
    before do
      subject.item = item
      allow(subject).to receive(:send_message).with(message).and_return(true)
    end
    it { expect(subject.update_item('tested', false)).to eq true }
  end

  describe '#send_message' do
    before do
      slack_notifier = double('Slack Notifier')
      allow(Slack::Notifier).to receive(:new).with(subject.slack_url).and_return(slack_notifier)
      allow(slack_notifier).to receive(:ping).with(message).and_return('message has been sent')
    end
    it { expect(subject.send_message(message)).to eq 'message has been sent' }
  end
end
