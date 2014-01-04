--------------------------------------------------------------------------
-- This is a simple program to implement Huffman compressed/decompression
-- Joe Wingbermuehle 20020315 <> 20020509
--------------------------------------------------------------------------

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Sequential_IO;
with Ada.Command_Line; use Ada.Command_Line;
with Ada.Unchecked_Deallocation;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

procedure Huffman is

	type Int8 is mod 2 ** 8;
	type Code_Type is array(0 .. 255) of boolean;

	package Binary_IO is new Ada.Sequential_IO(Int8);

	type Tree_Node;
	type Tree_Node_Pointer is access Tree_Node;
	type Tree_Node is record
		ch			: Int8;
		freq		: integer;
		left		: Tree_Node_Pointer;
		right		: Tree_Node_Pointer;
	end record;

	type Table_Node is record
		code		: Code_Type;
		length	: integer;
	end record;

	procedure Delete is new Ada.Unchecked_Deallocation(Tree_Node,
		Tree_Node_Pointer);

	inFile		: Binary_IO.File_Type;
	outFile		: Binary_IO.File_Type;
	charCount	: integer;
	treeCount	: integer;

	trees			: array(0 .. 255) of Tree_Node_Pointer;
	codeTable	: array(0 .. 255) of Table_Node;

	-----------------------------------------------------------------------
	-- Create the frequency table
	-----------------------------------------------------------------------
	procedure Create_Table is
		freq		: array(0 .. 255) of integer;
		mapping	: array(0 .. 255) of Int8;
		ch			: Int8;
		temp		: integer;
	begin
		charCount := 0;
		for x in 0 .. 255 loop
			freq(x) := 0;
			mapping(x) := Int8(x);
		end loop;
		while not Binary_IO.End_Of_File(inFile) loop
			Binary_IO.Read(inFile, ch);
			if freq(integer(ch)) = 0 then
				charCount := charCount + 1;
			end if;
			freq(integer(ch)) := freq(integer(ch)) + 1;
		end loop;
		Binary_IO.Reset(inFile);
		for x in 0 .. 255 - 1 loop
			for y in x + 1 .. 255 loop
				if (freq(x) > freq(y) and freq(y) /= 0) or freq(x) = 0 then
					temp := freq(x);
					freq(x) := freq(y);
					freq(y) := temp;
					ch := mapping(x);
					mapping(x) := mapping(y);
					mapping(y) := ch;
				end if;
			end loop;
		end loop;
		treeCount := charCount;
		for x in 0 .. charCount - 1 loop
			trees(x) := new Tree_Node;
			trees(x).ch := mapping(x);
			trees(x).freq := freq(x);
			trees(x).right := null;
			trees(x).left := null;
		end loop;
	end Create_Table;

	-----------------------------------------------------------------------
	-- Sort the trees by frequency
	-----------------------------------------------------------------------
	procedure Sort_Trees is
		temp		: Tree_Node_Pointer;
	begin
		for x in 0 .. treeCount - 2 loop
			for y in x + 1 .. treeCount - 1 loop
				if trees(x).freq > trees(y).freq then
					temp := trees(x);
					trees(x) := trees(y);
					trees(y) := temp;
				end if;
			end loop;
		end loop;
	end Sort_Trees;

	-----------------------------------------------------------------------
	-- Create a single tree from the frequency information
	-----------------------------------------------------------------------
	procedure Create_Tree is
		ptr		: Tree_Node_Pointer;
	begin
		while treeCount > 1 loop
			ptr := new Tree_Node;
			ptr.freq := trees(0).freq + trees(1).freq;
			ptr.left := trees(0);
			ptr.right := trees(1);
			trees(0) := ptr;
			treeCount := treeCount - 1;
			for x in 1 .. treeCount - 1 loop
				trees(x) := trees(x + 1);
			end loop;
			Sort_Trees;
		end loop;
	end Create_Tree;

	-----------------------------------------------------------------------
	-- Destroy a tree
	-----------------------------------------------------------------------
	procedure Destroy_Tree(root : in out Tree_Node_Pointer) is
	begin
		if root /= null then
			Destroy_Tree(root.left);
			Destroy_Tree(root.right);
			Delete(root);
		end if;
	end Destroy_Tree;

	-----------------------------------------------------------------------
	-- Shift a code left
	-----------------------------------------------------------------------
	procedure Shift_Left(code : in out Code_Type; amount : integer) is
	begin
		for x in 0 .. 255 - amount loop
			code(x) := code(x + amount);
		end loop;
		for x in 255 - amount + 1 .. 255 loop
			code(x) := false;
		end loop;
	end Shift_Left;

	-----------------------------------------------------------------------
	-- Clear a code
	-----------------------------------------------------------------------
	procedure Clear_Code(code : out Code_Type) is
	begin
		for x in 0 .. 255 loop
			code(x) := false;
		end loop;
	end Clear_Code;

	-----------------------------------------------------------------------
	-- Create a code table from a tree
	-----------------------------------------------------------------------
	procedure Create_Code_Table(root : Tree_Node_Pointer;
		code : Code_Type := (others => false); length : integer := 0) is
		temp		: Code_Type;
	begin
		if root.right /= null then
			temp := code;
			Shift_Left(temp, 1);
			temp(255) := true;
			Create_Code_Table(root.right, temp, length + 1);
		end if;
		if root.left /= null then
			temp := code;
			Shift_Left(temp, 1);
			temp(255) := false;
			Create_Code_Table(root.left, temp, length + 1);
		end if;
		if root.left = null and root.right = null then
			codeTable(integer(root.ch)).code := code;
			codeTable(integer(root.ch)).length := length;
		end if;
	end Create_Code_Table;

	-----------------------------------------------------------------------
	-- Write a byte to output
	-----------------------------------------------------------------------
	procedure Write_Byte(value : Int8) is
	begin
		Binary_IO.Write(outFile, value);
	end Write_Byte;

	-----------------------------------------------------------------------
	-- Read a byte from input
	-----------------------------------------------------------------------
	function Read_Byte return Int8 is
		ch		: Int8;
	begin
		Binary_IO.Read(inFile, ch);
		return ch;
	end Read_Byte;

	-----------------------------------------------------------------------
	-- Compress a file
	-----------------------------------------------------------------------
	procedure Compress is
		buffer		: Int8;
		length		: Int8;
		ch				: Int8;
		code			: Code_Type;
	begin
		Create_Table;
		Create_Tree;
		for x in 0 .. 255 loop
			codeTable(x).length := 0;
		end loop;
		Create_Code_Table(trees(0));
		Destroy_Tree(trees(0));

		-- Output the number of codes
		Write_Byte(Int8(charCount - 1));

		-- Output (value, length) pairs
		for x in 0 .. 255 loop
			if codeTable(x).length > 0 then
				Write_Byte(Int8(x));
				Write_Byte(Int8(codeTable(x).length - 1));
			end if;
		end loop;

		-- Output codes
		buffer := 0;
		length := 0;
		for x in 0 .. 255 loop
			if codeTable(x).length > 0 then
				code := codeTable(x).code;
				Shift_Left(code, 256 - codeTable(x).length);
				for y in 0 .. codeTable(x).length - 1 loop
					buffer := buffer * 2;
					if code(0) then
						buffer := buffer or 1;
					end if;
					Shift_Left(code, 1);
					length := length + 1;
					if length = 8 then
						Write_Byte(buffer);
						length := 0;
						buffer := 0;
					end if;
				end loop;
			end if;
		end loop;
		if length > 0 then
			buffer := buffer * 2 ** integer(8 - length);
			Write_Byte(buffer);
		end if;

		-- Write data
		Binary_IO.Reset(inFile);
		buffer := 0;
		length := 0;
		while not Binary_IO.End_Of_File(inFile) loop
			Binary_IO.Read(inFile, ch);
			code := codeTable(integer(ch)).code;
			Shift_Left(code, 256 - codeTable(integer(ch)).length);
			for x in 0 .. codeTable(integer(ch)).length - 1 loop
				buffer := buffer * 2;
				if code(0) then
					buffer := buffer or 1;
				end if;
				Shift_Left(code, 1);
				length := length + 1;
				if length = 8 then
					Write_Byte(buffer);
					buffer := 0;
					length := 0;
				end if;
			end loop;
		end loop;
		if length > 0 then
			buffer := buffer * 2 ** integer(8 - length);
			Write_Byte(buffer);
		end if;
	end Compress;

	-----------------------------------------------------------------------
	-- Decompress a file
	-----------------------------------------------------------------------
	procedure Decompress is
		ch					: Int8;
		length			: Int8;
		buffer			: Int8;
		code				: Code_Type;
		readLength		: integer;
	begin
		-- Read the size of the code table
		charCount := integer(Read_Byte) + 1;

		-- Read the (value, length) pairs
		for x in 0 .. 255 loop
			codeTable(x).length := 0;
		end loop;
		for x in 0 .. charCount - 1 loop
			ch := Read_Byte;
			codeTable(integer(ch)).length := integer(Read_Byte) + 1;
		end loop;

		-- Read the code data
		length := 1;
		buffer := 0;
		for x in 0 .. 255 loop
			Clear_Code(codeTable(x).code);
			for y in 0 .. codeTable(x).length - 1 loop
				length := length - 1;
				if length = 0 then
					Binary_IO.Read(inFile, buffer);
					length := 8;
				end if;
				Shift_Left(codeTable(x).code, 1);
				if (buffer and 128) /= 0 then
					codeTable(x).code(255) := true;
				end if;
				buffer := buffer * 2;
			end loop;
		end loop;

		-- Convert the data
		Clear_Code(code);
		readLength := 0;
		buffer := 0;
		length := 1;
		loop
			if Binary_IO.End_Of_File(inFile) then
				exit when readLength = 0;
			end if;
			buffer := buffer * 2;
			length := length - 1;
			if length = 0 then
				Binary_IO.Read(inFile, buffer);
				length := 8;
			end if;
			Shift_Left(code, 1);
			if (buffer and 128) /= 0 then
				code(255) := true;
			end if;
			readLength := readLength + 1;
			for x in 0 .. 255 loop
				if codeTable(x).length = readLength then
					if codeTable(x).code = code then
						Binary_IO.Write(outFile, Int8(x));
						Clear_Code(code);
						readLength := 0;
						exit;
					end if;
				end if;
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
		Put_Line("    -d    Decompress");
	end Display_Help;

	type Action_Type is (Compress, Decompress);

	action		: Action_Type;
	inName		: Unbounded_String;
	outName		: Unbounded_String;

--------------------------------------------------------------------------
-- Beginning of the main program
--------------------------------------------------------------------------
begin -- Compress

	if Argument_Count < 1 then
		Display_Help;
		return;
	end if;

	action := Compress;
	for x in 1 .. Argument_Count loop
		if Argument(x)(1) = '-' then
			if Argument(x)'length = 2 then
				case Argument(x)(2) is
					when 'd' =>
						action := Decompress;
					when others =>
						Display_Help;
						return;
				end case;
			else
				Display_Help;
				return;
			end if;
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
		outName := inName;
		Append(outName, ".huff");
	else
		if To_String(Tail(inName, 5)) /= ".huff" then
			Display_Help;
			return;
		else
			outName := Head(inName, Length(inName) - 5);
		end if;
	end if;

	Binary_IO.Open(File => inFile, Name => To_String(inName),
		Mode => Binary_IO.In_File);
	Binary_IO.Create(File => outFile, Name => To_String(outName));

	if action = Compress then
		Compress;
	else
		Decompress;
	end if;

	Binary_IO.Close(outFile);
	Binary_IO.Close(inFile);

end Huffman;

