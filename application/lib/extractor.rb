class Extractor
  attr_accessor :text
  def initialize text
    @text = text
  end

  def all
    # since telephone regex is more strict, remove duplicates
    books = self.books
    # no need, but for the future string.scan(/\d+/).join to remove all but numbers
    telephones = self.telephones
    books.delete_if {|x| telephones.include?(x)}

    {
      :books => books,
      :telephones => telephones,
      :emails => self.emails
    }
  end

  def books
    isbns = []
    self.text.scan(/(?<isbn>(\d[- ]?){9,12}([0-9xX]))/).each {|x| isbns << x[0]}
    isbns
  end

  def telephones
    telephones = []
    # comes out [prefix, XXX, XXX, XXXX, extension]
    self.text.scan(/\s(?:(?:\+?1\s*(?:[.-]\s*)?)?(?:\(\s*([2-9]1[02-9]|[2-9][02-8]1|[2-9][02-8][02-9])\s*\)|([2-9]1[02-9]|[2-9][02-8]1|[2-9][02-8][02-9]))\s*(?:[.-]\s*)?)?([2-9]1[02-9]|[2-9][02-9]1|[2-9][02-9]{2})\s*(?:[.-]\s*)?([0-9]{4})(?:\s*(?:#|x\.?|ext\.?|extension)\s*(\d+))?\s/).each do |x|
      phone = ""
      phone << "#{x[0]}-" unless x[0].nil?
      phone << "#{x[1]}-" unless x[1].nil?
      phone << "#{x[2]}-#{x[3]}"
      phone.gsub!(' ', '')
      phone << " x#{x[4]}" unless x[4].nil?
      telephones << phone
    end
    telephones
  end

  def emails
    emails = []
    self.text.scan(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}/i).each {|x| emails << x}
    emails
  end
end