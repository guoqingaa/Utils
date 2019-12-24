unit DynArray;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/Utils
//
// Implementation of an array with dynamic rank
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

Uses
  SysUtils;

Type
  TDynamicArrayIndex = record
  // This record converts between indices and a single composite index
  //
  // Example (composition of Index1 and Index2):
  //
  //    Index1   Index2   CompositeIndex
  //      0        0             0
  //      0        1             1
  //      1        0             2
  //      1        1             3
  private
    Count: Integer;
    Multipliers: array of Integer;
  public
    Constructor Create(const Shape: array of Integer);
    Procedure Reset; overload;
    Function Rank: Integer; inline;
    Function Shape: TArray<Integer>;
    Function Indices(CompositeIndex: Integer): TArray<Integer>;
    Function CompositeIndex(const Indices: array of Integer): Integer;
  end;

  TDynamicArray<T> = record
  // The multidimensional dynamic array stores its values in a one-dimensional array,
  // using a TDynamicArrayIndex-record to convert between indices and a single composite index.
  private
    FValues: TArray<T>;
    Index: TDynamicArrayIndex;
    Function GetValue(const Indices: array of Integer): T;
    Procedure SetValue(const Indices: array of Integer; const Value: T);
  public
    Class Operator Implicit(const Values: array of T): TDynamicArray<T>;
    Class Operator Implicit(const Values: TArray<T>): TDynamicArray<T>;
    Class Operator Implicit(const Values: TDynamicArray<T>): TArray<T>;
  public
    Constructor Create(const Shape: array of Integer);
    Function Allocated: Boolean;
    Procedure Allocate(const Shape: array of Integer);
    Function Rank: Integer; inline;
    Function Shape: TArray<Integer>; inline;
  public
    Property Value[const Indices: array of Integer]: T read GetValue write SetValue; default;
  end;

  TDynamicIntArray = TDynamicArray<Integer>;
  TDynamicFloatArray = TDynamicArray<Float64>;
  TDynamicFloat32Array = TDynamicArray<Float32>;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TDynamicArrayIndex.Create(Const Shape: array of Integer);
begin
  var Rank := Length(Shape);
  if Rank > 0 then
  begin
    Count := Shape[Rank-1];
    SetLength(Multipliers,Rank-1);
    for var Dim := Rank-2 downto 0 do
    begin
      Multipliers[Dim] := Count;
      Count := Count*Shape[Dim];
    end;
    if Count = 0 then raise Exception.Create('Invalid shape');
  end else Reset;
end;

Procedure TDynamicArrayIndex.Reset;
begin
  Count := 0;
  Finalize(Multipliers);
end;

Function TDynamicArrayIndex.Rank: Integer;
begin
  if Count = 0 then Result := 0 else Result := Length(Multipliers)+1;
end;

Function TDynamicArrayIndex.Shape: TArray<Integer>;
begin
  var Cnt := Count;
  SetLength(Result,Rank);
  for var Dim := low(Result) to pred(high(Result)) do
  begin
    Result[Dim] := Cnt div Multipliers[Dim];
    Cnt := Cnt div Result[Dim];
  end;
  Result[high(Result)] := Cnt;
end;

Function TDynamicArrayIndex.Indices(CompositeIndex: Integer): TArray<Integer>;
begin
  SetLength(Result,Rank);
  for var Dim := low(Result) to pred(high(Result)) do
  if CompositeIndex >= Multipliers[Dim] then
  begin
    Result[Dim] := CompositeIndex div Multipliers[Dim];
    CompositeIndex := CompositeIndex - Result[Dim]*Multipliers[Dim];
  end else Result[Dim] := 0;
  Result[high(Result)] := CompositeIndex;
end;

Function TDynamicArrayIndex.CompositeIndex(Const Indices: array of Integer): Integer;
begin
  if Length(Indices) = Rank then
  begin
    Result := Indices[Length(Multipliers)];
    for var Dim := low(Multipliers) to high(Multipliers) do
    Result := Result + Multipliers[Dim]*Indices[Dim];
  end else raise Exception.Create('Invalid rank');
end;

////////////////////////////////////////////////////////////////////////////////

Class Operator TDynamicArray<T>.Implicit(const Values: array of T): TDynamicArray<T>;
begin
  Result.Allocate([Length(Values)]);
  for var Index := low(Values) to high(Values) do Result.FValues[Index] := Values[Index];
end;

Class Operator TDynamicArray<T>.Implicit(const Values: TArray<T>): TDynamicArray<T>;
begin
  Result.Allocate([Length(Values)]);
  for var Index := low(Values) to high(Values) do Result.FValues[Index] := Values[Index];
end;

Class Operator TDynamicArray<T>.Implicit(const Values: TDynamicArray<T>): TArray<T>;
begin
  if Values.Rank = 1 then
    Result := Copy(Values.FValues,0,Length(Values.FValues))
  else
    raise Exception.Create('Invalid rank');
end;

Constructor TDynamicArray<T>.Create(const Shape: array of Integer);
begin
  Allocate(Shape);
end;

Function TDynamicArray<T>.Allocated: Boolean;
begin
  Result := Length(FValues) > 0;
end;

Procedure TDynamicArray<T>.Allocate(const Shape: array of Integer);
begin
  FValues := nil;
  Index := TDynamicArrayIndex.Create(Shape);
  SetLength(FValues,Index.Count);
end;

Function TDynamicArray<T>.Rank: Integer;
begin
  if Allocated then Result := Index.Rank else Result := 0;
end;

Function TDynamicArray<T>.Shape: TArray<Integer>;
begin
  Result := Index.Shape;
end;

Function TDynamicArray<T>.GetValue(const Indices: array of Integer): T;
begin
  if Length(Indices) = Rank then
    Result := FValues[Index.CompositeIndex(Indices)]
  else
    raise Exception.Create('Invalid rank');
end;

Procedure TDynamicArray<T>.SetValue(const Indices: array of Integer; const Value: T);
begin
  if Length(Indices) = Rank then
    FValues[Index.CompositeIndex(Indices)] := Value
  else
    raise Exception.Create('Invalid rank');
end;

end.