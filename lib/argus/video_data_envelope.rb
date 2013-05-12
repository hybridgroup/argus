module Argus
  class VideoDataEnvelope
    attr_reader :streamer

    def initialize(streamer)
      @streamer = streamer
      parse
    end

    def parse
      data(:signature, 4, "A*")
      data(:version, 1, "C")
      data(:video_codec, 1, "C")
      data(:header_size, 2, "v")
      data(:payload_size, 4, "V")
      data(:encoded_stream_width, 2, "v")
      data(:encoded_stream_height, 2, "v")
      data(:display_width, 2, "v")
      data(:display_height, 2, "v")
      data(:frame_number, 4, "V")
      data(:timestamp, 4, "V")
      data(:total_chunks, 1, "C")
      data(:chunk_index, 1, "C")
      data(:frame_type, 1, "C")
      data(:control, 1, "C")
      data(:stream_byte_position_lw, 4, "V")
      data(:stream_byte_position_uw, 4, "V")
      data(:stream_id, 2, "v")
      data(:total_slices, 1, "C")
      data(:slice_index, 1, "C")
      data(:header1_size, 1, "C")
      data(:header2_size, 1, "C")
      data(:reserved_2, 2, "H*")
      data(:advertised_size, 4, "V")
      data(:reserved_12, 12, "H*")
    end

    def data(name, size, format)
      define_data(name, get_data(size, format))
    end

    def get_data(size, format)
      streamer.read(size).unpack(format).first
    end

    def define_data(name, value)
      instance_variable_set(name, value)
      ivar = "@#{name}".to_sym
      define_method(name) {
        instance_variable_get(ivar)
      }
    end
  end
end