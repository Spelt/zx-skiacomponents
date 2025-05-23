{ ************************************************************************** }
{ *                                                                        * }
{ *                           Zx-SkiaComponents                            * }
{ *                                                                        * }
{ *           Copyright (c) 2025 Zx-SkiaComponents Project.                * }
{ *                                                                        * }
{ * Use of this source code is governed by the MIT license that can be     * }
{ * found in the LICENSE file.                                             * }
{ *                                                                        * }
{ ************************************************************************** }
unit Zx.TextControl;

{$IF CompilerVersion > 36}
{$MESSAGE WARN 'Check changes in FMX.Controls TTextControl implementation'}
{$ENDIF}

interface

{$I Zx.SkiaComponents.inc}
{$SCOPEDENUMS ON}

uses
  System.Classes,
  System.Types,
  System.Rtti,
  System.UITypes,
  System.Messaging,
  System.Math,
  System.ImageList,
  System.SysUtils,
  FMX.ActnList,
  FMX.Types,
  FMX.Objects,
  FMX.Ani,
  FMX.StdActns,
  FMX.Controls,
  FMX.Graphics,
  FMX.Controls.Presentation,
  FMX.Controls.Model,
  FMX.ImgList,
  FMX.AcceleratorKey,
{$IFDEF CompilerVersion < 36}
  Skia.FMX,
{$ELSE}
  FMX.Skia,
{$ENDIF}
  Zx.Controls;

type
  IZxPrefixStyle = interface
    ['{0415EB46-14CC-4F68-BE8D-02EA10ADA7E2}']
    function GetPrefixStyle: TPrefixStyle;
    procedure SetPrefixStyle(const AValue: TPrefixStyle);
    property PrefixStyle: TPrefixStyle read GetPrefixStyle write SetPrefixStyle;
  end;

  TZxTextControl = class(TZxStyledControl, ISkTextSettings, ICaption, IAcceleratorKeyReceiver, IZxPrefixStyle)
  public const
    DefaultPrefixStyle = TPrefixStyle.HidePrefix;
  private
    FTextSettingsInfo: TSkTextSettingsInfo;
    FTextObject: TControl;
    FITextSettings: ISkTextSettings;
    FText: string;
    FIsChanging: Boolean;
    FPrefixStyle: TPrefixStyle;
    FAcceleratorKey: Char;
    FAcceleratorKeyIndex: Integer;
    FAutoSize: Boolean;
    procedure SetAutoSize(const AValue: Boolean);
    { ISkTextSettings }
    function GetDefaultTextSettings: TSkTextSettings;
    function GetResultingTextSettings: TSkTextSettings;
    function GetTextSettings: TSkTextSettings;
    function GetStyledSettings: TStyledSettings;
    { ICaption }
    function GetText: string;
    function TextStored: Boolean;
    { IZxPrefixStyle }
    function GetPrefixStyle: TPrefixStyle;
    procedure SetPrefixStyle(const Value: TPrefixStyle);
  protected
    procedure UpdateTextObject(const TextControl: TControl; const Str: string);
    function TryAutoResize: Boolean;
    function HasFitSizeChanged: Boolean;
    procedure GetFitSize(var AWidth, AHeight: Single);
    { IAcceleratorKeyReceiver }
    function GetAcceleratorChar: Char;
    function GetAcceleratorCharIndex: Integer;

    property TextObject: TControl read FTextObject;
  protected
    function CustomTextSettingsClass: TSkTextSettingsInfo.TCustomTextSettingsClass; virtual;
    procedure TextSettingsChanged(Sender: TObject); virtual;
    function DoFilterControlText(const AText: string): string; virtual;
    procedure SetText(const Value: string); virtual;
    procedure SetTextInternal(const Value: string); virtual;
    function FindTextObject: TFmxObject; virtual;
    procedure DoTextChanged; virtual;
    procedure DoChanged; virtual;
    function GetFitWidth: Single; virtual;
    function GetFitHeight: Single; virtual;
    { ISkTextSettings }
    procedure SetTextSettings(const AValue: TSkTextSettings); virtual;
    procedure SetStyledSettings(const Value: TStyledSettings); virtual;
    function StyledSettingsStored: Boolean; virtual;
    { IAcceleratorKeyReceiver }
    procedure TriggerAcceleratorKey; virtual;
    function CanTriggerAcceleratorKey: Boolean; virtual;
  protected
    procedure Loaded; override;
    procedure SetName(const Value: TComponentName); override;
    function GetData: TValue; override;
    procedure SetData(const Value: TValue); override;
    procedure ActionChange(Sender: TBasicAction; CheckDefaults: Boolean); override;
    procedure DoRootChanging(const NewRoot: IRoot); override;
    procedure ApplyStyle; override;
    procedure FreeStyle; override;
    procedure DoStyleChanged; override;
    procedure DoEndUpdate; override;
    procedure SetAlign(const AValue: TAlignLayout); override;
    function DoSetSize(const ASize: TControlSize; const ANewPlatformDefault: Boolean; ANewWidth, ANewHeight: Single;
      var ALastWidth, ALastHeight: Single): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AfterConstruction; override;
    function ToString: string; override;

    procedure Change;
    property AutoSize: Boolean read FAutoSize write SetAutoSize;
    property Text: string read GetText write SetText stored TextStored;
    property PrefixStyle: TPrefixStyle read GetPrefixStyle write SetPrefixStyle default DefaultPrefixStyle;
    property DefaultTextSettings: TSkTextSettings read GetDefaultTextSettings;
    property ResultingTextSettings: TSkTextSettings read GetResultingTextSettings;
    property TextSettings: TSkTextSettings read GetTextSettings write SetTextSettings;
    property StyledSettings: TStyledSettings read GetStyledSettings write SetStyledSettings stored StyledSettingsStored;
  end;

implementation

uses
  System.Actions,
  System.UIConsts,
  System.Math.Vectors,
  FMX.Platform,
  FMX.BehaviorManager,
  FMX.Styles,
  Zx.Text,
  Zx.Helpers;

{ TZxTextControl }

constructor TZxTextControl.Create(AOwner: TComponent);
begin
  inherited;
  FIsChanging := True;
  EnableExecuteAction := True;
  FTextSettingsInfo := TSkTextSettingsInfo.Create(Self, CustomTextSettingsClass);
  FTextSettingsInfo.Design := csDesigning in ComponentState;
  FTextSettingsInfo.OnChange := TextSettingsChanged;
  FPrefixStyle := DefaultPrefixStyle;
  FAcceleratorKey := #0;
  FAcceleratorKeyIndex := -1;
end;

procedure TZxTextControl.AfterConstruction;
begin
  inherited;
  FIsChanging := False;
end;

destructor TZxTextControl.Destroy;
var
  AccelKeyService: IFMXAcceleratorKeyRegistryService;
begin
  if TPlatformServices.Current.SupportsPlatformService(IFMXAcceleratorKeyRegistryService, AccelKeyService) then
    AccelKeyService.UnregisterReceiver(Root, Self);
  FTextSettingsInfo.Free;
  inherited;
end;

procedure TZxTextControl.ActionChange(Sender: TBasicAction; CheckDefaults: Boolean);
begin
  if Sender is TCustomAction then
  begin
    if (not CheckDefaults) or (Text = '') or (Text = Name) then
      Text := TCustomAction(Sender).Text;
  end;
  inherited;
end;

function TZxTextControl.CanTriggerAcceleratorKey: Boolean;
begin
  Result := ParentedVisible;
end;

procedure TZxTextControl.Change;
begin
  if not FIsChanging and ([csLoading, csDestroying] * ComponentState = []) then
  begin
    FIsChanging := True;
    try
      DoChanged;
      TryAutoResize;
    finally
      FIsChanging := False;
    end;
  end;
end;

procedure TZxTextControl.DoChanged;
var
  TextStr: string;
begin
  if FITextSettings <> nil then
    FITextSettings.TextSettings.BeginUpdate;
  try
    if FITextSettings <> nil then
      FITextSettings.TextSettings.Assign(ResultingTextSettings);
    if FPrefixStyle = TPrefixStyle.HidePrefix then
      TextStr := DelAmp(Text)
    else
      TextStr := Text;

    TextStr := DoFilterControlText(TextStr);

    if FTextObject <> nil then
      UpdateTextObject(FTextObject, TextStr)
    else if ResourceControl <> nil then
      UpdateTextObject(ResourceControl, TextStr)
    else
    begin
      if not TryAutoResize then
        Redraw;
      UpdateEffects;
    end;
  finally
    if FITextSettings <> nil then
      FITextSettings.TextSettings.EndUpdate;
  end;
end;

procedure TZxTextControl.DoEndUpdate;
begin
  inherited;
  if ([csLoading, csDestroying] * ComponentState = []) then
    Change;
end;

function TZxTextControl.DoFilterControlText(const AText: string): string;
begin
  Result := Text;
end;

procedure TZxTextControl.DoRootChanging(const NewRoot: IRoot);
var
  AccelKeyService: IFMXAcceleratorKeyRegistryService;
begin
  if TPlatformServices.Current.SupportsPlatformService(IFMXAcceleratorKeyRegistryService, AccelKeyService) then
    AccelKeyService.ChangeReceiverRoot(Self, Root, NewRoot);
  inherited;
end;

function TZxTextControl.DoSetSize(const ASize: TControlSize; const ANewPlatformDefault: Boolean; ANewWidth, ANewHeight: Single;
  var ALastWidth, ALastHeight: Single): Boolean;
begin
  if FAutoSize and not(csLoading in ComponentState) then
    GetFitSize(ANewWidth, ANewHeight);
  Result := inherited;
end;

procedure TZxTextControl.DoStyleChanged;
var
  NewT: string;
begin
  inherited;
  if AutoTranslate and (Text <> '') then
  begin
    NewT := Translate(Text); // need for collection texts
    if not(csDesigning in ComponentState) then
      Text := NewT;
  end;
end;

procedure TZxTextControl.DoTextChanged;
begin

end;

function TZxTextControl.FindTextObject: TFmxObject;
begin
  Result := FindStyleResource('text');
end;

procedure TZxTextControl.ApplyStyle;
var
  S: TBrushObject;
  NewT: string;
  FontBehavior: IFontBehavior;
  AccelKeyService: IFMXAcceleratorKeyRegistryService;

  procedure SetupDefaultTextSetting(const AObject: TFmxObject; var AITextSettings: ISkTextSettings; var ATextObject: TControl;
    const ADefaultTextSettings: TSkTextSettings);
  var
    LFMXTextSettings: ITextSettings;
    NewFamily: string;
    NewSize: Single;
  begin
    AITextSettings := nil;
    ATextObject := nil;
    if ADefaultTextSettings <> nil then
    begin
      if Supports(AObject, ISkTextSettings, AITextSettings) then
        ADefaultTextSettings.Assign(AITextSettings.TextSettings)
      else if Supports(AObject, ITextSettings, LFMXTextSettings) then
        ADefaultTextSettings.Assign(LFMXTextSettings.TextSettings)
      else
        ADefaultTextSettings.Assign(nil);

      if FontBehavior <> nil then
      begin
        NewFamily := '';
        FontBehavior.GetDefaultFontFamily(Scene.GetObject, NewFamily);
        if NewFamily <> '' then
          ADefaultTextSettings.Font.Families := NewFamily;

        NewSize := 0;
        FontBehavior.GetDefaultFontSize(Scene.GetObject, NewSize);
        if not SameValue(NewSize, 0, TEpsilon.FontSize) then
          ADefaultTextSettings.Font.Size := NewSize;
      end;
    end;
    if (AObject is TControl) then
      ATextObject := TControl(AObject)
  end;

begin
  ResultingTextSettings.BeginUpdate;
  try
    FTextSettingsInfo.Design := False;
    { behavior }
    if Scene <> nil then
      TBehaviorServices.Current.SupportsBehaviorService(IFontBehavior, FontBehavior, Scene.GetObject);
    { from text }
    SetupDefaultTextSetting(FindTextObject, FITextSettings, FTextObject, FTextSettingsInfo.DefaultTextSettings);
    inherited;
    { from foreground }
    if FindStyleResource<TBrushObject>('foreground', S) then
    begin
      // use instead of the black, foreground color
      if (FTextSettingsInfo.DefaultTextSettings.FontColor = claBlack) or
        (FTextSettingsInfo.DefaultTextSettings.FontColor = claNull) then
        FTextSettingsInfo.DefaultTextSettings.FontColor := S.Brush.Color;
    end;
  finally
    ResultingTextSettings.EndUpdate;
    FTextSettingsInfo.Design := csDesigning in ComponentState;
  end;
  if TPlatformServices.Current.SupportsPlatformService(IFMXAcceleratorKeyRegistryService, AccelKeyService) then
    AccelKeyService.RegisterReceiver(Root, Self);
  if AutoTranslate and (FText <> '') then
  begin
    NewT := Translate(Text); // need for collection texts
    if not(csDesigning in ComponentState) then
      Text := NewT;
  end;
  Change;
end;

procedure TZxTextControl.FreeStyle;
var
  AccelKeyService: IFMXAcceleratorKeyRegistryService;
begin
  if TPlatformServices.Current.SupportsPlatformService(IFMXAcceleratorKeyRegistryService, AccelKeyService) then
    AccelKeyService.UnregisterReceiver(Root, Self);

  if FITextSettings <> nil then
    FITextSettings.TextSettings := FITextSettings.DefaultTextSettings;
  FITextSettings := nil;
  FTextObject := nil;
  inherited;
end;

procedure TZxTextControl.Loaded;
begin
  inherited;
  Change;
  FTextSettingsInfo.Design := csDesigning in ComponentState;
end;

function TZxTextControl.GetAcceleratorChar: Char;
var
  AccelKeyService: IFMXAcceleratorKeyRegistryService;
begin
  if (FAcceleratorKeyIndex < 0) and TPlatformServices.Current.SupportsPlatformService(IFMXAcceleratorKeyRegistryService,
    AccelKeyService) then
    AccelKeyService.ExtractAcceleratorKey(Text, FAcceleratorKey, FAcceleratorKeyIndex);

  Result := FAcceleratorKey;
end;

function TZxTextControl.GetAcceleratorCharIndex: Integer;
var
  AccelKeyService: IFMXAcceleratorKeyRegistryService;
begin
  if (FAcceleratorKeyIndex < 0) and TPlatformServices.Current.SupportsPlatformService(IFMXAcceleratorKeyRegistryService,
    AccelKeyService) then
    AccelKeyService.ExtractAcceleratorKey(Text, FAcceleratorKey, FAcceleratorKeyIndex);

  Result := FAcceleratorKeyIndex;
end;

function TZxTextControl.GetData: TValue;
begin
  Result := Text;
end;

function TZxTextControl.GetDefaultTextSettings: TSkTextSettings;
begin
  Result := FTextSettingsInfo.DefaultTextSettings;
end;

procedure TZxTextControl.GetFitSize(var AWidth, AHeight: Single);

  function InternalGetFitHeight: Single;
  begin
    case Align of
      TAlignLayout.Client, TAlignLayout.Contents, TAlignLayout.Left, TAlignLayout.MostLeft, TAlignLayout.Right,
        TAlignLayout.MostRight, TAlignLayout.FitLeft, TAlignLayout.FitRight, TAlignLayout.HorzCenter, TAlignLayout.Vertical:
        Result := AHeight;
    else
      Result := GetFitHeight;
    end;
  end;

  function InternalGetFitWidth: Single;
  begin
    case Align of
      TAlignLayout.Client, TAlignLayout.Contents, TAlignLayout.Top, TAlignLayout.MostTop, TAlignLayout.Bottom,
        TAlignLayout.MostBottom, TAlignLayout.VertCenter, TAlignLayout.Horizontal:
        Result := AWidth;
    else
      Result := GetFitWidth;
    end;
  end;

begin
  AWidth := InternalGetFitWidth;
  AHeight := InternalGetFitHeight;
end;

function TZxTextControl.GetFitHeight: Single;

  function GetControlHeight(const AControl: TControl; const AUseTextFitBounds: Boolean): Single;
  begin
    Result := 0;
    if AControl = nil then
      Exit;
    for var LControl in AControl.Controls do
      if LControl.Visible then
        if AUseTextFitBounds and (LControl is TSkLabel) then
          Result := Result + LControl.Margins.Top + TSkLabel(LControl).FitBounds.Height + LControl.Margins.Bottom
        else if AUseTextFitBounds and Supports(LControl, IZxText) then
          Result := Result + LControl.Margins.Top + (LControl as IZxText).ParagraphBounds.Height + LControl.Margins.Bottom
        else if not(LControl.Align in [TAlignLayout.Client, TAlignLayout.Contents, TAlignLayout.Left, TAlignLayout.MostLeft,
          TAlignLayout.Right, TAlignLayout.MostRight, TAlignLayout.FitLeft, TAlignLayout.FitRight, TAlignLayout.HorzCenter,
          TAlignLayout.Vertical]) then
          Result := Result + LControl.Margins.Top + LControl.Height + LControl.Margins.Bottom;
    if Result <> 0 then
      Result := Result + AControl.Padding.Top + AControl.Padding.Bottom;
  end;

begin
  Result := Ceil(GetControlHeight(Self, False) + GetControlHeight(ResourceControl, True));
  if Result = 0 then
    Result := Height;
end;

function TZxTextControl.GetFitWidth: Single;

  function GetControlWidth(const AControl: TControl; const AUseTextFitBounds: Boolean): Single;
  begin
    Result := 0;
    if AControl = nil then
      Exit;
    for var LControl in AControl.Controls do
      if LControl.Visible then
        if AUseTextFitBounds and (LControl is TSkLabel) then
          Result := Result + LControl.Margins.Left + TSkLabel(LControl).FitBounds.Width + LControl.Margins.Right
        else if AUseTextFitBounds and Supports(LControl, IZxText) then
          Result := Result + LControl.Margins.Left + (LControl as IZxText).ParagraphBounds.Width + LControl.Margins.Right
        else if not(LControl.Align in [TAlignLayout.Client, TAlignLayout.Contents, TAlignLayout.Top, TAlignLayout.MostTop,
          TAlignLayout.Bottom, TAlignLayout.MostBottom, TAlignLayout.VertCenter, TAlignLayout.Horizontal]) then
          Result := Result + LControl.Margins.Left + LControl.Width + LControl.Margins.Right;
    if Result <> 0 then
      Result := Result + AControl.Padding.Left + AControl.Padding.Right;
  end;

begin
  Result := Ceil(GetControlWidth(Self, False) + GetControlWidth(ResourceControl, True));
  if Result = 0 then
    Result := Width;
end;

function TZxTextControl.GetPrefixStyle: TPrefixStyle;
begin
  Result := FPrefixStyle;
end;

function TZxTextControl.GetResultingTextSettings: TSkTextSettings;
begin
  Result := FTextSettingsInfo.ResultingTextSettings;
end;

function TZxTextControl.GetStyledSettings: TStyledSettings;
begin
  Result := FTextSettingsInfo.StyledSettings;
end;

function TZxTextControl.GetText: string;
begin
  Result := FText;
end;

function TZxTextControl.GetTextSettings: TSkTextSettings;
begin
  Result := FTextSettingsInfo.TextSettings;
end;

function TZxTextControl.HasFitSizeChanged: Boolean;
var
  LNewWidth: Single;
  LNewHeight: Single;
begin
  LNewWidth := Width;
  LNewHeight := Height;
  GetFitSize(LNewWidth, LNewHeight);
  Result := (not SameValue(LNewWidth, Width, TEpsilon.Position)) or (not SameValue(LNewHeight, Height, TEpsilon.Position));
end;

procedure TZxTextControl.SetAlign(const AValue: TAlignLayout);
begin
  if (Align <> AValue) and AutoSize then
  begin
    inherited;
    SetSize(Width, Height);
  end
  else
    inherited;
end;

procedure TZxTextControl.SetAutoSize(const AValue: Boolean);
begin
  if FAutoSize <> AValue then
  begin
    FAutoSize := AValue;
    SetSize(Width, Height);
  end;
end;

procedure TZxTextControl.SetData(const Value: TValue);
begin
  if Value.IsEmpty then
    Text := ''
  else
    Text := Value.ToString;
end;

procedure TZxTextControl.SetName(const Value: TComponentName);
var
  ChangeText: Boolean;
begin
  ChangeText := not(csLoading in ComponentState) and (Name = Text) and
    ((Owner = nil) or not(Owner is TComponent) or not(csLoading in TComponent(Owner).ComponentState));
  inherited SetName(Value);
  if ChangeText then
    Text := Value;
end;

procedure TZxTextControl.SetPrefixStyle(const Value: TPrefixStyle);
begin
  if FPrefixStyle <> Value then
  begin
    FPrefixStyle := Value;
    if FText.Contains('&') then
      if (FUpdating = 0) and ([csUpdating, csLoading, csDestroying] * ComponentState = []) then
      begin
        ApplyStyleLookup;
        Change;
      end;
  end;
end;

procedure TZxTextControl.SetStyledSettings(const Value: TStyledSettings);
begin
  FTextSettingsInfo.StyledSettings := Value;
end;

procedure TZxTextControl.SetText(const Value: string);
var
  AccelKeyService: IFMXAcceleratorKeyRegistryService;
begin
  if FText <> Value then
  begin
    FText := Value;
    if TPlatformServices.Current.SupportsPlatformService(IFMXAcceleratorKeyRegistryService, AccelKeyService) and (Root <> nil)
    then
      AccelKeyService.RegisterReceiver(Root, Self);
    if (FUpdating = 0) and ([csUpdating, csLoading, csDestroying] * ComponentState = []) then
    begin
      ApplyStyleLookup;
      Change;
      DoTextChanged;
    end;
  end;
end;

procedure TZxTextControl.SetTextInternal(const Value: string);
begin
  if FText <> Value then
  begin
    FText := Value;
    ApplyStyleLookup;
    Change;
  end;
end;

procedure TZxTextControl.SetTextSettings(const AValue: TSkTextSettings);
begin
  FTextSettingsInfo.TextSettings.Assign(AValue);
end;

function TZxTextControl.StyledSettingsStored: Boolean;
begin
  Result := StyledSettings <> DefaultStyledSettings;
end;

function TZxTextControl.CustomTextSettingsClass: TSkTextSettingsInfo.TCustomTextSettingsClass;
begin
  Result := nil;
end;

procedure TZxTextControl.TextSettingsChanged(Sender: TObject);
begin
  if csLoading in ComponentState then
    Exit;
  ApplyStyleLookup;
  Change;
end;

function TZxTextControl.TextStored: Boolean;
begin
  Result := ((Text <> '') and (not ActionClient)) or
    (not(ActionClient and (ActionLink <> nil) and (ActionLink.CaptionLinked) and (Action is TContainedAction)));
end;

function TZxTextControl.ToString: string;
begin
  Result := Format('%s ''%s''', [inherited ToString, FText]);
end;

procedure TZxTextControl.TriggerAcceleratorKey;
begin
  SetFocus;
end;

function TZxTextControl.TryAutoResize: Boolean;
begin
  Result := not IsUpdating and FAutoSize and HasFitSizeChanged;
  if Result then
    SetSize(Width, Height);
end;

procedure TZxTextControl.UpdateTextObject(const TextControl: TControl; const Str: string);
var
  Caption: ICaption;
  PrefixStyle: IZxPrefixStyle;
begin
  if TextControl = nil then
    Exit;
  if Supports(TextControl, IZxPrefixStyle, PrefixStyle) then
    PrefixStyle.PrefixStyle := FPrefixStyle
  else if TextControl is TText then
    TText(TextControl).PrefixStyle := FPrefixStyle;
  if Supports(TextControl, ICaption, Caption) then
    Caption.Text := Str;
  TextControl.UpdateEffects;
  UpdateEffects;
  if not TryAutoResize then
    if TextControl is TSkCustomControl then
      TSkCustomControl(TextControl).Redraw
    else
      TextControl.Repaint;
end;

end.
