--------------------------------------------------------------------------
-- A simple program to implement Lempel-Ziv-Welch (de)compression
-- Joe Wingbermuehle 20020313 <> 20020509
--------------------------------------------------------------------------

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Sequential_IO;
with Ada.Command_Line; use Ada.Command_Line;

procedure LZW is

	Dictionary_Size	: constant integer := 4095;
	Terminator			: constant integer := 4095;

	dictionary	: array(0 .. Dictionary_Size - 1) of Unbounded_String;
	offset		: integer range 0 .. Dictionary_Size;

	type Int8 is mod 2 ** 8;
	type Int12 is mod 2 ** 12;
	type Int24 is mod 2 ** 24;
	type Action_Type is (Compress, Decompress);

	package Binary_IO is new Ada.Sequential_IO(Int8);

	type File_Data_Type is record
		fd			: Binary_IO.File_Type;
		buffer	: Int24;
		pending	: boolean;
	end record;

	inFile		: File_Data_Type;
	outFile		: File_Data_Type;
	inName		: Unbounded_String;
	outName		: Unbounded_String;
	action		: Action_Type;

	-----------------------------------------------------------------------
	-- Check if a string is in the dictionary and get its index
	-----------------------------------------------------------------------
	function Get_Table_Index(word : Unbounded_String) return integer is
	begin
		for x in 0 .. offset - 1 loop
			if word = dictionary(x) then
				return x;
			end if;
		end loop;
		return -1;
	end Get_Table_Index;

	-----------------------------------------------------------------------
	-- Write 12 bits to the output file
	-----------------------------------------------------------------------
	procedure Write_12Bits(value : Int12) is
		byte		: Int8;
		temp		: Int24;
	begin
		if outFile.pending then
			temp := outFile.buffer or Int24(value);
			byte := Int8((temp and 16#FF0000#) / (2 ** 16));
			Binary_IO.Write(outFile.fd, byte);
			byte := Int8((temp and 16#00FF00#) / (2 ** 8));
			Binary_IO.Write(outFile.fd, byte);
			byte := Int8((temp and 16#0000FF#));
			Binary_IO.Write(outFile.fd, byte);
			outFile.pending := false;
			outFile.buffer := 0;
		else
			outFile.buffer := Int24(value) * (2 ** 12);
			outFile.pending := true;
		end if;
	end Write_12Bits;

	-----------------------------------------------------------------------
	-- Read 12 bits from the input file
	-----------------------------------------------------------------------
	function Read_12Bits return Int12 is
		value		: Int12;
		byte		: Int8;
	begin
		if inFile.pending then
			value := Int12(inFile.buffer and 16#000FFF#);
			inFile.pending := false;
			return value;
		else
			Binary_IO.Read(inFile.fd, byte);
			inFile.buffer := Int24(byte) * (2 ** 16);
			Binary_IO.Read(inFile.fd, byte);
			inFile.buffer := inFile.buffer or (Int24(byte) * (2 ** 8));
			Binary_IO.Read(inFile.fd, byte);
			inFile.buffer := inFile.buffer or Int24(byte);
			value := Int12((inFile.buffer and 16#FFF000#) / (2 ** 12));
			inFile.pending := true;
			return value;
		end if;
	end Read_12Bits;

	-----------------------------------------------------------------------
	-- Write a byte to the output file
	-----------------------------------------------------------------------
	procedure Write_Byte(value : Int8) is
	begin
		Binary_IO.Write(outFile.fd, value);
	end Write_Byte;

	-----------------------------------------------------------------------
	-- Read a byte from the input file
	-----------------------------------------------------------------------
	function Read_Byte return Int8 is
		value		: Int8;
	begin
		Binary_IO.Read(inFile.fd, value);
		return value;
	end Read_Byte;

	-----------------------------------------------------------------------
	-- Open a decompressed file for reading
	-----------------------------------------------------------------------
	procedure Open_Uncompressed(name : string) is
	begin
		Binary_IO.Open(File => inFile.fd, Name => name,
			Mode => Binary_IO.In_File);
	end Open_Uncompressed;

	-----------------------------------------------------------------------
	-- Open a compressed file for reading
	-----------------------------------------------------------------------
	procedure Open_Compressed(name : string) is
	begin
		Binary_IO.Open(File => inFile.fd, Name => name,
			Mode => Binary_IO.In_File);
		inFile.pending := false;
		inFile.buffer := 0;
	end Open_Compressed;

	-----------------------------------------------------------------------
	-- Open a file for writing the decomrpessed output
	-----------------------------------------------------------------------
	procedure Create_Uncompressed(name : string) is
	begin
		Binary_IO.Create(File => outFile.fd, Name => name);
	end Create_Uncompressed;

	-----------------------------------------------------------------------
	-- Open a file for writing compressed output
	-----------------------------------------------------------------------
	procedure Create_Compressed(name : string) is
	begin
		Binary_IO.Create(File => outFile.fd, Name => name);
		outFile.pending := false;
		outFile.buffer := 0;
	end Create_Compressed;

	-----------------------------------------------------------------------
	-- Intialize the dictionary
	-----------------------------------------------------------------------
	procedure Initialize_Dictionary is
	begin
		for x in 0 .. 255 loop
			dictionary(x) := To_Unbounded_String("");
			Append(dictionary(x), character'val(x));
		end loop;
		offset := 256;
	end Initialize_Dictionary;

	-----------------------------------------------------------------------
	-- Run the compression algorithm
	-----------------------------------------------------------------------
	procedure Compress is
		byte		: Int8;
		word		: Unbounded_String;
		index		: integer;
		last		: integer;
	begin
		Initialize_Dictionary;
		last := 0;
		word := To_Unbounded_String("");
		while not Binary_IO.End_Of_File(inFile.fd) loop
			byte := Read_Byte;
			Append(word, character'val(byte));
			index := Get_Table_Index(word);
			if index < 0 then
				if offset < Dictionary_Size then
					dictionary(offset) := word;
					offset := offset + 1;
				end if;
				Write_12Bits(Int12(last));
				word := Tail(word, 1);
				index := Get_Table_Index(word);
			end if;
			last := index;
		end loop;
		Write_12Bits(Int12(last));
		-- Write terminator twice so that at least one makes it out
		Write_12Bits(Int12(Terminator));
		Write_12Bits(Int12(Terminator));
	end Compress;

	-----------------------------------------------------------------------
	-- Run the decompression algorithm
	-----------------------------------------------------------------------
	procedure Decompress is
		code		: Int12;
		word		: Unbounded_String;
		last		: Unbounded_String;
		newEntry	: Unbounded_String;
	begin
		Initialize_Dictionary;
		last := To_Unbounded_String("");
		loop
			code := Read_12Bits;
			exit when integer(code) = Terminator;
			if integer(code) >= offset then
				word := word & Head(word, 1);
				if offset < Dictionary_Size then
					dictionary(offset) := word;
					offset := offset + 1;
				end if;
				last := word;
			else
				word := dictionary(integer(code));
				if offset < Dictionary_Size then
					newEntry := last & Head(word, 1);
					if Get_Table_Index(newEntry) < 0 then
						dictionary(offset) := newEntry;
						offset := offset + 1;
					end if;
					last := word;
				end if;
			end if;
			for x in 1 .. Length(word) loop
				Write_Byte(Int8(character'pos(Element(word, x))));
			end loop;
		end loop;
	end Decompress;

	-----------------------------------------------------------------------
	-- Display help
	-----------------------------------------------------------------------
	procedure Display_Help is
	begin
		Put_Line("usage: " & Command_Name & " [options] <filename>");
		Put_Line("options:");
		Put_Line("    -d     decompress");
	end Display_Help;

--------------------------------------------------------------------------
-- Beginning of the main program
--------------------------------------------------------------------------
begin

	if Argument_Count < 1 then
		Display_Help;
		return;
	end if;

	action := Compress;
	for x in 1 .. Argument_Count loop
		if Argument(x)(1) = '-' then
			case Argument(x)(2) is
				when 'd' =>
					action := Decompress;
				when others =>
					Display_Help;
					return;
			end case;
		else
			if Length(inName) = 0 then
				inName := To_Unbounded_String(Argument(x));
			else
				Display_Help;
				return;
			end if;
		end if;
	end loop;

	if Length(inName) = 0 then
		Display_Help;
		return;
	end if;

	if action = Compress then
		outName := inName & To_Unbounded_String(".lzw");
	else
		if Length(inName) < 5
			and then Tail(inName, 4) /= To_Unbounded_String(".lzw") then
			Display_Help;
			return;
		end if;
		outName := Head(inName, Length(inName) - 4);
	end if;

	if action = Compress then
		Open_Uncompressed(To_String(inName));
		Create_Compressed(To_String(outName));
		Compress;
		Binary_IO.Close(inFile.fd);
		Binary_IO.Close(outFile.fd);
	else
		Open_Compressed(To_String(inName));
		Create_Uncompressed(To_String(outName));
		Decompress;
		Binary_IO.Close(inFile.fd);
		Binary_IO.Close(outFile.fd);
	end if;

end LZW;

