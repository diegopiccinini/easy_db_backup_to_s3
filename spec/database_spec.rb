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
    describe '#upate_item' do
      let(:item) { { 'database' => 'test2', 'datehour' => 10000 } }
      before do
        subject.update_item(item, { 'new_attr' => { value: 'new_value' , action: 'PUT' }})
        sleep 2
      end
      let(:read) { subject.item(item['database'], item['datehour']) }
      it { expect(read.item['new_attr']).to eq 'new_value' }
    end
  end
end
