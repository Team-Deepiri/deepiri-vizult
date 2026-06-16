# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'spec_helper'
require 'deepiri_vizult/graph'
require 'deepiri_vizult/service_registry'
require 'deepiri_vizult/resolvers/path_resolver'
require 'deepiri_vizult/scanners/project_files'
require 'deepiri_vizult/scanners/topic_constants'
require 'deepiri_vizult/scanners/stream_scanner'

RSpec.describe DeepiriVizult::Scanners::StreamScanner do
  let(:tmpdir) { Dir.mktmpdir('vizult-stream') }

  after { FileUtils.remove_entry(tmpdir) }

  def run_scan
    graph = DeepiriVizult::Graph.new
    registry = DeepiriVizult::ServiceRegistry.new
    registry.register('svc', source_dirs: [tmpdir])
    described_class.new(root: tmpdir, graph: graph, registry: registry, max_depth: 8).scan
    graph
  end

  def stream_labels(graph)
    graph.nodes.values.select { |n| n[:type] == :stream }.map { |n| n[:label] }
  end

  it 'detects a string-literal topic split across lines (multi-line call)' do
    File.write(File.join(tmpdir, 'pub.py'), <<~PY)
      async def go():
          await client.xadd(
              "training-events",
              event,
          )
    PY

    graph = run_scan
    expect(stream_labels(graph)).to include('training-events')
    edge = graph.edges.find { |e| e[:type] == :publishes }
    expect(edge[:to]).to eq('stream:training-events')
    expect(edge[:from]).to eq('service:svc')
  end

  it 'resolves a constant reference to its real topic value' do
    File.write(File.join(tmpdir, 'topics.py'), <<~PY)
      from enum import Enum

      class StreamTopics(str, Enum):
          PLATFORM_EVENTS = "platform-events"
          MODEL_EVENTS = "model-events"
    PY
    File.write(File.join(tmpdir, 'publisher.py'), <<~PY)
      async def emit():
          await client.publish(StreamTopics.PLATFORM_EVENTS, event)
    PY

    graph = run_scan
    expect(stream_labels(graph)).to include('platform-events')
    edge = graph.edges.find { |e| e[:type] == :publishes }
    expect(edge[:metadata][:topic_const]).to eq('StreamTopics.PLATFORM_EVENTS')
  end

  it 'resolves a TS enum constant reference' do
    File.write(File.join(tmpdir, 'topics.ts'), <<~TS)
      export enum StreamTopics {
        INFERENCE_EVENTS = 'inference-events',
        PLATFORM_EVENTS = 'platform-events',
      }
    TS
    File.write(File.join(tmpdir, 'publisher.ts'), <<~TS)
      streamingClient.publish(StreamTopics.INFERENCE_EVENTS, event);
    TS

    graph = run_scan
    expect(stream_labels(graph)).to include('inference-events')
  end

  it 'drops constant references that cannot be resolved (no junk symbol nodes)' do
    File.write(File.join(tmpdir, 'publisher.py'), <<~PY)
      async def emit():
          await client.publish(UnknownTopics.MYSTERY, event)
    PY

    graph = run_scan
    expect(stream_labels(graph)).to be_empty
  end

  it 'filters Redis special IDs and punctuation-only captures' do
    File.write(File.join(tmpdir, 'consumer.py'), <<~PY)
      async def loop():
          messages = await redis.xreadgroup(group, name, {topic: ">"})
          await client.publish(topic=".", event)
    PY

    graph = run_scan
    expect(stream_labels(graph)).to be_empty
  end
end
