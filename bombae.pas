program Bombae;

uses Termio;

const
    STDIN_FILENO = 0;

    // un-hardcode field rows and cols
    HardcodedFieldRows = 15;
    HardcodedFieldCols = 15;
    HardcodedBombsPercentage = 17;

type
    Cell = (Empty, Bomb);
    State = (Closed, Open, Flagged);
    Field = record
        Generated: Boolean;
        Cells: array of array of Cell;
        States: array of array of State;
        Rows: Integer;
        Cols: Integer;
        CursorRow: Integer;
        CursorCol: Integer;
{$ifdef DEBUG}
        Peek: Boolean;
{$endif}
    end;
    YornKeep = (KeepNone = 0, KeepYes = 1, KeepNo = 2, KeepBoth = 3);

function IsVictory(Field: Field): Boolean;
var
    Row, Col: Integer;
begin
    with Field do
        for Row := 0 to Rows-1 do
            for Col := 0 to Cols-1 do
                case States[Row][Col] of
            Open:            if Cells[Row][Col] <> Empty then Exit(False);
            Closed, Flagged: if Cells[Row][Col] <> Bomb  then Exit(False);
        end;
        IsVictory := True;
    end;

procedure FlagAtCursor(var Field: Field);
begin
    with Field do
        case States[CursorRow][CursorCol] of
    Closed:  States[CursorRow][CursorCol] := Flagged;
    Flagged: States[CursorRow][CursorCol] := Closed;
end
   end;

procedure RandomCell(Field: Field; var Row, Col: Integer);
begin
    Row := Random(Field.Rows);
    Col := Random(Field.Cols);
end;

function IsAroundCursor(Field: Field; Row, Col: Integer): Boolean;
var
    DRow, DCol: Integer;
begin
    for DRow := -1 to 1 do
        for DCol := -1 to 1 do
            if (Field.CursorRow + DRow = Row) and (Field.CursorCol + DCol = Col) then
                Exit(True);
            IsAroundCursor := False;
        end;

procedure FieldRandomize(var Field: Field; BombsPercentage: Integer);
var
    Index, BombsCount: Integer;
    Row, Col: Integer;
begin
    with Field do
    begin
        for Row := 0 to Rows - 1 do
            for Col := 0 to Cols - 1 do
                Cells[Row][Col] := Empty;
            if BombsPercentage > 100 then BombsPercentage := 100;
            BombsCount := (Rows*Cols*BombsPercentage + 99) div 100;
            for Index := 1 to BombsCount do
            begin
                repeat
                    RandomCell(Field, Row, Col)
                until (Cells[Row][Col] <> Bomb) and not IsAroundCursor(Field, Row, Col);
                Cells[Row][Col] := Bomb;
            end;
        end;
    end;

function FieldContains(Field: Field; Row, Col: Integer): Boolean;
begin
    FieldContains := (0 <= Row) and (Row < Field.Rows) and (0 <= Col) and (Col < Field.Cols);
end;

function CountNborBombs(Field: Field; Row, Col: Integer): Integer;
var
    DRow, DCol: Integer;
begin
    CountNborBombs := 0;
    with Field do
        for DRow := -1 to 1 do
            for DCol := -1 to 1 do
                if (DRow <> 0) or (DCol <> 0) then
                    if FieldContains(Field, Row + DRow, Col + DCol) then
                        if Cells[Row + DRow][Col + DCol] = Bomb then
                            Inc(CountNborBombs);
                    end;

function CountNborFlags(Field: Field; Row, Col: Integer): Integer;
var
    DRow, DCol: Integer;
begin
    CountNborFlags := 0;
    with Field do
        for DRow := -1 to 1 do
            for DCol := -1 to 1 do
                if (DRow <> 0) or (DCol <> 0) then
                    if FieldContains(Field, Row + DRow, Col + DCol) then
                        if States[Row + DRow][Col + DCol] = Flagged then
                            Inc(CountNborFlags);
                    end;

function OpenAt(var Field: Field; Row, Col: Integer): Boolean;
var
    DRow, DCol: Integer;
begin
    with Field do
    begin
        if not Generated then
        begin
            FieldRandomize(Field, HardcodedBombsPercentage);
            Generated := True;
        end;

        States[Row][Col] := Open;

        if CountNborBombs(Field, Row, Col) = CountNborFlags(Field, Row, Col) then
            for DRow := -1 to 1 do
                for DCol := -1 to 1 do
                    if FieldContains(Field, DRow + Row, DCol + Col) then
                        if States[DRow + Row][DCol + Col] = Closed then
                            if OpenAt(Field, DRow + Row, DCol + Col) then
                                Exit(True);

                            OpenAt := Cells[Row][Col] = Bomb;
                        end
                    end;

function OpenAtCursor(var Field: Field): Boolean;
begin
    OpenAtCursor := OpenAt(Field, Field.CursorRow, Field.CursorCol);
end;

procedure FlagAllBombs(var Field: Field);
var
    Row, Col: Integer;
begin
    with Field do
        for Row := 0 to Rows - 1 do
            for Col := 0 to Cols - 1 do
                if Cells[Row][Col] = Bomb then
                    States[Row][Col] := Flagged;
            end;

procedure OpenAllBombs(var Field: Field);
var
    Row, Col: Integer;
begin
    with Field do
        for Row := 0 to Rows - 1 do
            for Col := 0 to Cols - 1 do
                if Cells[Row][Col] = Bomb then
                    States[Row][Col] := Open;
            end;

procedure FieldReset(var Field: Field; Rows, Cols: Integer);
var
    Row, Col: Integer;
begin
    Field.Generated := False;
    Field.CursorRow := 0;
    Field.CursorCol := 0;
    SetLength(Field.Cells, Rows, Cols);
    SetLength(Field.States, Rows, Cols);
    Field.Rows := Rows;
    Field.Cols := Cols;
    for Row := 0 to Rows - 1 do
        for Col := 0 to Cols - 1 do
            Field.States[Row][Col] := Closed;
{$ifdef DEBUG}
        Field.Peek := False;
{$endif}
    end;

function IsAtCursor(Field: Field; Row, Col: Integer): Boolean;
begin
    IsAtCursor := (Field.CursorRow = Row) and (Field.CursorCol = Col);
end;

procedure FieldDisplay(Field: Field);
var
    Row, Col, Nbors: Integer;
begin
    with Field do
        for Row := 0 to Rows-1 do
        begin
            for Col := 0 to Cols-1 do
            begin
                if IsAtCursor(Field, Row, Col) then Write('[') else Write(' ');
{$ifdef DEBUG}
                if Peek then
                    case Cells[Row][Col] of
                Bomb: Write('@');
                Empty: begin
                    Nbors := CountNborBombs(Field, Row, Col);
                    if Nbors > 0 then Write(Nbors) else Write(' ');
                end;
            end
            else
{$endif}
                case States[Row][Col] of
            Open: case Cells[Row][Col] of
            Bomb: Write('@');
            Empty: begin
                Nbors := CountNborBombs(Field, Row, Col);
                if Nbors > 0 then Write(Nbors) else Write(' ');
            end;
        end;
        Closed: Write('.');
        Flagged: Write('%');
    end;
    if IsAtCursor(Field, Row, Col) then Write(']') else Write(' ');
end;
WriteLn
         end
     end;

procedure MoveUp(var Field: Field);
begin
    with Field do if CursorRow > 0 then Dec(CursorRow);
end;

procedure MoveDown(var Field: Field);
begin
    with Field do if CursorRow < Rows-1 then Inc(CursorRow);
end;

procedure MoveLeft(var Field: Field);
begin
    with Field do if CursorCol > 0 then Dec(CursorCol);
end;

procedure MoveRight(var Field: Field);
begin
    with Field do if CursorCol < Cols-1 then Inc(CursorCol);
end;

procedure FieldRedisplay(Field: Field);
begin
    Write(Chr(27), '[', Field.Rows,   'A');
    Write(Chr(27), '[', Field.Cols*3, 'D');
    FieldDisplay(Field);
end;

function YorN(Question: String; Keep: YornKeep): Boolean;
var
    Answer: Char;
begin
    Write(Question, ' [y/n] ');
    while True do
    begin
        Read(Answer);
        case Answer of
        'y', 'Y', ' ', Chr(10):
        begin
            if (Integer(Keep) and 1) = 1
            then WriteLn('y')
        else Write(Chr(13), Chr(27), '[2K');
        Exit(True)
    end;
    'n', 'N', Chr(27):
    begin
        if ((Integer(Keep) shr 1) and 1) = 1
        then WriteLn('n')
    else Write(Chr(13), Chr(27), '[2K');
    Exit(False)
end;
         end;
     end;
 end;

function StateAtCursor(Field: Field): State;
begin
    with Field do StateAtCursor := States[CursorRow][CursorCol];
end;

var
    MainField: Field;
    SavedTAttr, TAttr: Termios;
    Cmd: Char;
    Quit: Boolean;
begin
    Randomize;

    if IsATTY(STDIN_FILENO) = 0 then
    begin
        WriteLn('ERROR: this is not a terminal!');
        Halt(1);
    end;
    TCGetAttr(STDIN_FILENO, TAttr);
    TCGetAttr(STDIN_FILENO, SavedTAttr);
    TAttr.c_lflag := TAttr.c_lflag and (not (ICANON or ECHO));
    TAttr.c_cc[VMIN] := 1;
    TAttr.c_cc[VTIME] := 0;
    TCSetAttr(STDIN_FILENO, TCSAFLUSH, &tattr);

    FieldReset(MainField, HardcodedFieldRows, HardcodedFieldCols);
    FieldDisplay(MainField);

    Quit := False;
    while not Quit do
    begin
        Read(Cmd);
        case Cmd of
        'k': begin
            MoveUp(MainField);
            FieldRedisplay(MainField);
        end;
        'j': begin
            MoveDown(MainField);
            FieldRedisplay(MainField);
        end;
        'h': begin
            MoveLeft(MainField);
            FieldRedisplay(MainField);
        end;
        'l': begin
            MoveRight(MainField);
            FieldRedisplay(MainField);
        end;
        'f': begin
            FlagAtCursor(MainField);
            FieldRedisplay(MainField);
        end;
        'r': if YorN('restart?', KeepYes) then
        begin
            FieldReset(MainField, HardcodedFieldRows, HardcodedFieldCols);
            FieldDisplay(MainField);
        end;
        'q', Chr(27): Quit := YorN('quit?', KeepYes);
{$ifdef DEBUG}
        'p': begin
            MainField.Peek := not MainField.Peek;
            FieldRedisplay(MainField);
        end;
{$endif}
        ' ': begin
            if (StateAtCursor(MainField) <> Flagged) or YorN('really open flagged cell?', KeepNone) then
                if OpenAtCursor(MainField) then
                begin
                    {TODO: indicate which bomb caused the explosion}
                    OpenAllBombs(MainField);
                    FieldRedisplay(MainField);
                    if YorN('you died! restart?', KeepBoth) then
                    begin
                        FieldReset(MainField, HardcodedFieldRows, HardcodedFieldCols);
                        FieldDisplay(MainField);
                    end
                    else Quit := True;
                end
                else
                begin
                    if IsVictory(MainField) then
                    begin
                        FlagAllBombs(MainField);
                        FieldRedisplay(MainField);
                        if YorN('you won! restart?', KeepBoth) then
                        begin
                            FieldReset(MainField, HardcodedFieldRows, HardcodedFieldCols);
                            FieldDisplay(MainField);
                        end
                        else Quit := True
                    end
                    else FieldRedisplay(MainField);
                end
            end;
        end;
    end;

    TCSetAttr(STDIN_FILENO, TCSANOW, SavedTAttr);
end.
