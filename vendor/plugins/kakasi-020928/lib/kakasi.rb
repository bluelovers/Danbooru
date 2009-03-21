module Kakasi
  def normalize_chouon(src)
    src.gsub(/([aiou])\s*\^/) do
      $1 + $1
    end.gsub(/e\s*\^/, "ei")
  end
  
  def utf8_kakasi(src)
    begin
      eucjp_src = Iconv.iconv("EUC-JP", "UTF-8", src)
      result = kakasi("-oeuc -ieuc -p -Ja -Ha -Ka", eucjp_src.join(""))
      utf8_src = Iconv.iconv("UTF-8", "EUC-JP", result).join("")
      return normalize_chouon(utf8_src)
    rescue Iconv::IllegalSequence, Iconv::InvalidCharacter
      return "Input string was not properly UTF-8 formatted"
    end
  end
  
  module_function :normalize_chouon
  module_function :utf8_kakasi
end
