#!/bin/env ruby

$KCODE = "u"
require 'jcode'
require 'rubygems'
require 'postgres'
require 'utf8proc'
require 'pp'

class Romanizer
  def initialize(options = {})
    options[:db_host] ||= "127.0.0.1"
    options[:db_name] ||= "ja_dict"

    @packages = ["small"]
    @db = PGconn.new(options[:db_host], nil, nil, nil, options[:db_name])
    @kana_hash = {}

    %w(~a a ~i i ~u u ~e e ~o o ka ga ki gi ku gu ke ge ko go sa za shi ji su zu se ze so zo ta da chi ji ~tu tsu zu te de to do na ni nu ne no ha ba pa hi bi pi hu bu pu he be pe ho bo po ma mi mu me mo ~ya ya ~yu yu ~yo yo ra ri ru re ro ~wa wa wi we wo n vu ~ka ~ke).each_with_index do |char, i|
      @kana_hash[0x3041 + i] = char
      @kana_hash[0x30A1 + i] = char
    end
 
    @kana_hash[0x30FC] = "--"
  end

  def close
    @db.close
  end

  def packages=(packages)
    @packages = packages.downcase.scan(/[a-z]+/)
  end

  # Normalizes an array of romanji characters, transforming internal
  # escape characters into standard form.
  def normalize_romanji(chars)
    normalized = []
    i = 0

    while i < chars.size
      if chars[i].is_a?(Array)
        normalized << normalize_romanji(chars[i])
        i += 1
        next
      end

      char = chars[i]
      next_char = chars[i + 1].to_s

      if char == "n"
        if next_char =~ /[bmp]/
          normalized << "m"
        else
          normalized << "n"
        end

      elsif char == "~tu"
        normalized << (next_char[0, 1] + next_char)
        i += 1
        
      elsif char =~ /i$/ && next_char =~ /^~y/
        head = char[0..-2]
        tail = next_char[1..-1]

        tail.gsub!(/^y/, "") if head =~ /^.h|^j/
        normalized << (head + tail)
        i += 1

      elsif char =~ /o$/ && next_char =~ /^~?o$/
        normalized << (char + "u")
        i += 1

      elsif char == "--"
        prev_char = normalized.pop
        prev_char += prev_char[-1, 1]
        normalized << prev_char

      else
        normalized << char
      end

      i += 1
    end

    return normalized.map {|x| x.is_a?(Array) ? x : x.gsub(/~/, "")}
  end

  def normalize_japanese(x)
    return x.utf8nfkc
  end

  # Romanizes a single kana character.
  def romanize_char(x)
    bytes = x.unpack("C*")
    return x if bytes.size != 3
    ucs2 = ((bytes[0] & 0x0F) << 12) | ((bytes[1] & 0x3F) << 6) | (bytes[2] & 0x3F)
    return @kana_hash[ucs2] || x
  end

  def is_kana?(x)
    bytes = x.unpack("C*")
    return false if bytes.size != 3
    ucs2 = ((bytes[0] & 0x0F) << 12) | ((bytes[1] & 0x3F) << 6) | (bytes[2] & 0x3F)
    return ucs2 >= 0x3040 && ucs2 <= 0x30FF
  end

  def is_kanji?(x)
    bytes = x.unpack("C*")
    return false if bytes.size != 3
    ucs2 = ((bytes[0] & 0x0F) << 12) | ((bytes[1] & 0x3F) << 6) | (bytes[2] & 0x3F)
    return ucs2 >= 0x3400 && ucs2 <= 0x9FFF
  end

  def is_japanese?(x)
    return is_kana?(x) || is_kanji?(x)
  end

  def query_db(word)
    sql = "SELECT kana FROM dict WHERE kanji = $JA$%s$JA$ AND package IN (%s)" % [word, "'" + @packages.join("', '") + "'"]
    results = @db.exec(sql).result
  end

  def parse_query(query)
    tokens = query.scan(/[\xe3-\xe9]..|\xef[\xbd-\xbe].|[^\xe3-\xe9]+/).map do |x|
      if x.size == 3
        normalize_japanese(x)
      else
        x
      end
    end
  end

  def to_romanji(kana)
    kana.map do |x|
      if x.is_a?(String)
        romanize_char(x)
      else
        to_romanji(x)
      end
    end
  end

  def join_romanji(s)
    s.map do |x|
      if x.is_a?(Array)
        " " + x.map {|y| y.join("")}.join("/") + " "
      else
        x
      end
    end.join("").gsub(/^\s+|\s+$/, '').gsub(/\s{2,}/, ' ')
  end

  def romanize(query)
    tokens = parse_query(query)
    original, kana = to_kana(tokens)
    romanji = to_romanji(kana)
    normalized_romanji = normalize_romanji(romanji)
    return join_romanji(normalized_romanji)
  end

  def to_kana(characters)
    i1 = 0
    original = []
    translated = []
    characters << "~"

    while i1 < characters.size
      if is_kanji?(characters[i1])
        i2 = i1
        prev_matches = []

        while i2 < characters.size
          word = characters[i1..i2]
          matches = query_db(word.join("")).flatten
          if matches.empty?
            if word.size == 1
              original << word.join("")
              translated << ["?"]
            else
              original << word[0..-2].join("")
              translated << prev_matches.map {|x| parse_query(x)}
            end
            break
          else
            prev_matches = matches
          end

          i2 += 1
        end

        i1 = i2
      else
        original << characters[i1]
        translated << characters[i1]
        i1 += 1
      end
    end

    if original[-1] == "~"
      original.delete_at(-1)
    end

    if translated[-1] == "~"
      translated.delete_at(-1)
    end

    return [original, translated]
  end
end

