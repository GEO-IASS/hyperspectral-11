module IMZML
  class Metadata

    module FlowRateArray
      RATE_32_BIT_FLOAT = "MS:1000521"
      RATE_64_BIT_FLOAT = "MS:1000523"
    end

    attr_accessor :uuid
    attr_accessor :sha1

  end
end