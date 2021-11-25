# typed: true
# frozen_string_literal: true

require 'ddtrace/profiling/flush'
require 'ddtrace/profiling/pprof/code_identification'
require 'ddtrace/profiling/pprof/message_set'
require 'ddtrace/profiling/pprof/string_table'
require 'ddtrace/utils/time'

module Datadog
  module Profiling
    module Pprof
      # Accumulates profile data and produces a Perftools::Profiles::Profile
      class Builder
        DEFAULT_ENCODING = 'UTF-8'
        DESC_FRAME_OMITTED = 'frame omitted'
        DESC_FRAMES_OMITTED = 'frames omitted'

        attr_reader \
          :functions,
          :locations,
          :mappings,
          :sample_types,
          :samples,
          :string_table

        def initialize
          @functions = MessageSet.new(1)
          @locations = initialize_locations_hash
          @mappings = MessageSet.new(1) { |filename, _| filename.hash }
          @sample_types = MessageSet.new
          @samples = []
          @string_table = StringTable.new

          # Cache this proc, since it's pretty expensive to keep recreating it
          @build_function = method(:build_function).to_proc
          @build_mapping = method(:build_mapping).to_proc

          @code_identification = CodeIdentification.new(mapping_id_for: method(:mapping_id_for).to_proc)
        end

        # The locations hash maps unique BacktraceLocation instances to their corresponding pprof Location objects;
        # there's a 1:1 correspondence, since BacktraceLocations were already deduped
        def initialize_locations_hash
          sequence = Utils::Sequence.new(1)
          Hash.new do |locations_hash, backtrace_location|
            locations_hash[backtrace_location] = build_location(sequence.next, backtrace_location)
          end
        end

        def encode_profile(profile)
          Perftools::Profiles::Profile.encode(profile).force_encoding(DEFAULT_ENCODING)
        end

        def build_profile(start:, finish:)
          start_ns = Datadog::Utils::Time.as_utc_epoch_ns(start)
          finish_ns = Datadog::Utils::Time.as_utc_epoch_ns(finish)

          Perftools::Profiles::Profile.new(
            sample_type: @sample_types.messages,
            sample: @samples,
            mapping: @mappings.messages,
            location: @locations.values,
            function: @functions.messages,
            string_table: @string_table.strings,
            time_nanos: start_ns,
            duration_nanos: finish_ns - start_ns,
          )
        end

        def build_value_type(type, unit)
          Perftools::Profiles::ValueType.new(
            type: @string_table.fetch(type),
            unit: @string_table.fetch(unit)
          )
        end

        def build_locations(backtrace_locations, length)
          locations = backtrace_locations.collect { |backtrace_location| @locations[backtrace_location] }

          omitted = length - backtrace_locations.length

          # Add placeholder stack frame if frames were truncated
          if omitted > 0
            desc = omitted == 1 ? DESC_FRAME_OMITTED : DESC_FRAMES_OMITTED
            locations << @locations[Profiling::BacktraceLocation.new('', 0, "#{omitted} #{desc}")]
          end

          locations
        end

        def build_location(id, backtrace_location)
          Perftools::Profiles::Location.new(
            id: id,
            line: [build_line(
              @functions.fetch(
                backtrace_location.path,
                backtrace_location.base_label,
                &@build_function
              ).id,
              backtrace_location.lineno
            )],
            mapping_id: @code_identification.mapping_for(backtrace_location.path),
          )
        end

        def build_line(function_id, line_number)
          Perftools::Profiles::Line.new(
            function_id: function_id,
            line: line_number
          )
        end

        def build_function(id, filename, function_name)
          Perftools::Profiles::Function.new(
            id: id,
            name: @string_table.fetch(function_name),
            filename: @string_table.fetch(filename)
          )
        end

        def build_mapping(id, filename, build_id = nil)
          Perftools::Profiles::Mapping.new(
            id: id,
            filename: @string_table.fetch(filename),
            build_id: build_id && @string_table.fetch(build_id),
          )
        end

        def mapping_id_for(filename:, build_id:)
          @mappings.fetch(filename, build_id, &@build_mapping).id
        end
      end
    end
  end
end
