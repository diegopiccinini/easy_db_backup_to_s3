# frozen_string_literal: true

require 'spec_helper'

describe Database do
  context '#write' do
    let(:write) do
      subject.item('test2', 10001, false)
    end
    let(:item) do
      subject.item('test2', 10001)
    end
    describe '#item write' do
      before do
        write
        item
      end
      it { expect(subject.result.item['tested']).to eq false }
    end
  end
  context '#last' do
    let(:write) do
      subject.item('test2', 10000, true)
    end
    let(:last) do
      subject.last('test2')
    end
    let(:first) do
      subject.first('test2')
    end
    describe '#item write' do
      before do
        write
      end
      it { expect(last['tested']).to eq false }
      it { expect(first['tested']).to eq true }
    end
  end
end
