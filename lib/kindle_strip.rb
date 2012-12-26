require "kindle_strip/version"

module KindleStrip
  OFFSET_UNIQUE_ID_SEED = 68
  OFFSET_NUMBER_OF_RECORDS = 76
  OFFSET_RECORD_INFO = 78

  extend self

  def strip_srcs(input)
    if input[0x3c, 8] != "BOOKMOBI"
      raise "MobiPocket marker not found"
    end
    num_records = uint16_be(input, OFFSET_NUMBER_OF_RECORDS)
    record0 = get_record0(input)
    srcs_start = uint32_be(record0, 0xe0)
    srcs_count = uint32_be(record0, 0xe4)
    if srcs_start == 0xffffffff || srcs_count == 0
      raise "File doesn't contain SRCS"
    end
    srcs_offset = uint32_be(input, OFFSET_RECORD_INFO + srcs_start * 8)
    srcs_length = uint32_be(input, OFFSET_RECORD_INFO + (srcs_start + srcs_count) * 8) - srcs_offset
    if input[srcs_offset, 4] != "SRCS"
      raise "SRCS section num does not point to SRCS"
    end

    output = new_header(input, num_records - srcs_count)
    output += new_record_infos(input, num_records, srcs_start, srcs_count, srcs_length)
    output += make_padding(output)
    output += new_records(input, srcs_offset, srcs_length)
    fix_record0(record0, srcs_start, srcs_count)
    set_record0(output, record0)
    output
  end

  def get_record0(buf)
    record0_offset = uint32_be(buf, OFFSET_RECORD_INFO)
    record1_offset = uint32_be(buf, OFFSET_RECORD_INFO + 8)
    buf[record0_offset ... record1_offset]
  end
  private :get_record0

  def set_record0(buf, record0)
    record0_offset = uint32_be(buf, OFFSET_RECORD_INFO)
    record1_offset = uint32_be(buf, OFFSET_RECORD_INFO + 8)
    buf[record0_offset ... record1_offset] = record0
  end
  private :set_record0

  def new_header(input, num_records)
    header = input[0 ... OFFSET_RECORD_INFO]
    header[OFFSET_UNIQUE_ID_SEED, 4] = [num_records * 2 + 1].pack("N")
    header[OFFSET_NUMBER_OF_RECORDS, 2] = [num_records].pack("n")
    header
  end
  private :new_header

  def new_record_infos(input, num_records, srcs_start, srcs_count, srcs_length)
    srcs_end = srcs_start + srcs_count
    record_infos = ""
    num_records.times do |i|
      next if (srcs_start ... srcs_end) === i
      offset = uint32_be(input, OFFSET_RECORD_INFO + i * 8)
      attr_and_id = uint32_be(input, OFFSET_RECORD_INFO + i * 8 + 4)
      offset -= srcs_count * 8
      if i >= srcs_end
        offset -= srcs_length
        attr_and_id = (i - srcs_count) * 2 | (attr_and_id & 0xff000000)
      end
      record_infos += [offset, attr_and_id].pack("NN")
    end
    record_infos
  end
  private :new_record_infos

  def make_padding(output)
    record_offset = uint32_be(output, OFFSET_RECORD_INFO)
    "\0" * (record_offset - output.length)  # padding by NUL
  end
  private :make_padding

  def new_records(input, srcs_offset, srcs_length)
    record_offset = uint32_be(input, OFFSET_RECORD_INFO)
    records = input[record_offset .. -1]
    records[srcs_offset - record_offset, srcs_length] = ""  # remove SRCS
    records
  end
  private :new_records

  def fix_record0(record0, srcs_start, srcs_count)
    record0[0xe0, 8] = [0xffffffff, 0].pack("NN")  # set no SRCS
    fix_exth(record0, srcs_start, srcs_count)
  end
  private :fix_record0

  def fix_exth(record0, srcs_start, srcs_count)
    unless uint32_be(record0, 0x80) & 0x40
      # no EXTH header
      return
    end
    exth_offset = 16 + uint32_be(record0, 0x14)
    exth = record0[exth_offset .. -1]
    if exth[0, 4] != "EXTH"
      # marker not found
      return
    end
    num_records = uint32_be(exth, 8)
    pos = 12
    num_records.times do |i|
      type = uint32_be(exth, pos)
      size = uint32_be(exth, pos + 4)
      if type == 121
        boundary = uint32_be(exth, pos + 8)
        if srcs_start <= boundary
          record0[exth_offset + pos + 8, 4] = [boundary - srcs_count].pack("N")
        end
      end
      pos += size
    end
  end
  private :fix_exth

  def uint16_be(buf, offset = 0)
    buf.unpack("@#{offset}n").first
  end
  private :uint16_be

  def uint32_be(buf, offset = 0)
    buf.unpack("@#{offset}N").first
  end
  private :uint32_be
end
