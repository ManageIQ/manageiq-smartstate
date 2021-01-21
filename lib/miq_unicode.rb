module ManageIQ
  module UnicodeString
    refine String do
      def UnicodeToUtf8
        dup.UnicodeToUtf8!
      end

      def UnicodeToUtf8!
        force_encoding("UTF-16LE").encode!("UTF-8")
      end

      def Utf8ToUnicode
        dup.Utf8ToUnicode!
      end

      def Utf8ToUnicode!
        force_encoding("UTF-8").encode!("UTF-16LE")
      end

      def AsciiToUtf8
        dup.AsciiToUtf8!
      end

      def AsciiToUtf8!
        force_encoding("ISO-8859-1").encode!("UTF-8")
      end

      def Utf8ToAscii
        dup.Utf8ToAscii!
      end

      def Utf8ToAscii!
        force_encoding("UTF-8").encode!("ISO-8859-1")
      end

      def Ucs2ToAscii
        dup.Ucs2ToAscii!
      end

      def Ucs2ToAscii!
        force_encoding("UTF-16LE").encode!("ISO-8859-1")
      end
    end
  end
end
