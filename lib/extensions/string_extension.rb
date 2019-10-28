module StringExtension
  def rpad(num, char = ' ')
    self.ljust(num, char)
  end
end
