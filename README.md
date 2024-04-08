# ZX Skia components
<a href="#compatibility"><img src="https://img.shields.io/static/v1?label=RAD%20Studio&message=11%2B&color=silver&style=flat&logo=delphi&logoColor=white" alt="Delphi 11+ support" /></a>

An open-source set of Delphi components for the FireMonkey framework that utilizes the **[Skia4Delphi](https://skia4delphi.org)** library.

# Summary
- [Base controls](#base-controls)
- [Svg components](#svg-components)
  - [TZxSvgGlyph](#tzxsvgglyph)
  - [TZxSvgBrushList](#tzxsvgbrushlist)
- [Text components](#text-components)
  - [TZxText](#tzxtext)
  - [TZxTextControl](#tzxtextcontrol)
  - [TZxCustomButton](#tzxcustombutton)
    - [TZxButton, TZxSpeedButton](#tzxbutton-and-tzxspeedbutton)
- [FMX style objects - revamped](#fmx-style-objects---revamped)
  - [TZxCustomActiveStyleObject](#tzxcustomactivestyleobject)
    - [TZxColorActiveStyleObject](#tzxcoloractivestyleobject)
    - [TZxAnimatedImageActiveStyleObject](#tzxanimatedimageactivestyleobject)
  - [TZxCustomButtonStyleObject](#tzxcustombuttonstyleobject)
    - [TZxColorButtonStyleObject](#tzxcolorbuttonstyleobject)
- [Adding default style for components](#adding-default-style-for-components)
  - [How to use](#how-to-use)
  - [Advantages and disadvantages](#advantages-and-disadvantages)

## Base controls
ZX defines the `TZxCustomControl` and `TZxStyledControl` classes, which inherit from `TSkCustomControl` and `TSkStyledControl`, respectively. They implement only a workaround for an FMX behavior on mobile platforms: panning and releasing execute _Click_ on the control on which you released your finger. This is especially annoying when you're scrolling through clickable components. The most simple workaround I found was the following:
```delphi
procedure TZxCustomControl.Click;
begin
{$IFDEF ZX_FIXMOBILECLICK}
  if FManualClick then
{$ENDIF}
    inherited;
  DoClick;
end;

procedure TZxCustomControl.Tap(const Point: TPointF);
begin
{$IFDEF ZX_FIXMOBILECLICK}
  FManualClick := True;
  Click;
  FManualClick := False;
{$ENDIF}
  inherited;
  DoTap(Point);
end;
```
This way, _Click_ only executes from the _Tap_ method, and _Tap_ is executed only if the internal calculation concluded it was a tap, not a pan. With this implementation, it is enough to assign only _OnClick_ events for all platforms, instead of assigning both _OnClick_ and _OnTap_ events, and then wrap the _OnClick_ implementation into a compiler directive condition.

_Note:_ I left this feature disabled by default since I'm unsure how the community will receive it (and it may break some existing code). I've also marked both _Click_ and _Tap_ methods as _final_ overrides and added new _DoClick_ and _DoTap_ methods, since otherwise, it is easy to break the fix by overriding the _Click_ method in a child class. To enable it, go to _Project > Options > Delphi Compiler_, and in _Conditional defines_ add `ZX_FIXMOBILECLICK`.

## Svg components
Thanks to _skia4delphi_, we have a proper [SVG support](https://github.com/skia4delphi/skia4delphi/blob/main/Documents/SVG.md) in Delphi!

### TZxSvgGlyph
ZX provides a new glyph component that draws SVG instead of a bitmap. The class implements the `IGlyph` interface and is almost the same implementation as in `TGlyph` (with properties such as _AutoHide_) but without all the bitmap-related code.

### TZxSvgBrushList
This class inherits from `TBaseImageList` and is a collection of `TSkSvgBrush` items. This implementation allows you to, for example, attach the `TZxSvgBrushList` component to a `TActionList.ImageList`, and then use the brushes by assigning `TAction.ImageIndex`. To display an item, use the above-mentioned `TZxSvgGlyph`.
**Note:** The component does not yet have a design-time editor, so currently it is possible to manipulate it only through the _Structure view_.

## Text components
Since the arrival of _skia4delphi_, we're able to:
- manipulate more text settings with the `TSkTextSettings`, such as _MaxLines_, _LetterSpacing_, font's _Weight_ and _Stretch_, etc.
- define a [custom style](https://github.com/skia4delphi/skia4delphi/blob/main/Documents/LABEL.md#firemonkey-styles) for text settings, and
- retrieve the true text size before the draw occurs.

### TZxText
Reimplementation of FMX's `TText` control that implements `ISkTextSettings` instead of `ITextSettings`. There are 2 major differences when compared to `TText`:
1. Parent class is `TZxStyledControl`, meaning it can be styled through the _StyleLookup_ property. The control expects the [TSkStyleTextObject](https://github.com/skia4delphi/skia4delphi/blob/main/Documents/LABEL.md#firemonkey-styles) in its style object and applies the text settings according to its _StyledSettings_ property. This way you can define and change your text settings in one place!
2. It contains a published _AutoSize_ property, which is self-explanatory. If you wish to retrieve the text size in runtime without having the _AutoSize_ property set to _True_, use the public property _ParagraphBounds_, which returns a _TRectF_ value.

### TZxTextControl
The FMX framework defines `TTextControl` and `TPresentedTextControl` classes, which serve as a base for all text controls, such as `TButton`, `TListBoxItem`, etc. They rely on their style objects to contain the `TText` control, whose _TextSettings_ can be modified in the Style Designer. Unfortunately, integrating those features into the mentioned base FMX classes is like getting blood from a stone, so ZX reimplemented the `TTextControl` into `TZxTextControl`, which utilizes `ISkTextSettings` instead of `ITextSettings`. The implementation is similar, except it contains the _AutoSize_ property. If true, the control will resize to the _TZxText.ParagraphBounds_ and any other objects (depending on their alignment and visibility) from its style resource.

### TZxCustomButton
This class implements the same functionality as FMX's `TCustomButton`, except its property _Images_ is a `TBaseImageList` instead of `TCustomImageList`, which allows you to assign both `TZxSvgBrushList` ([mentioned earlier](#TZxSvgBrushList)) and `TImageList`. If using the former, the style resource should contain the `TZxSvgGlyph` ([mentioned earlier](#TZxSvgGlyph)) component with _StyleName_ set to '_glyph_'.

#### TZxButton and TZxSpeedButton
These classes are the same as their counterparts, `TButton` and `TSpeedButton`.

## FMX style objects - revamped
The current FMX's approach to the application style relies on [```TBitmapLinks```](https://docwiki.embarcadero.com/Libraries/Athens/en/FMX.Styles.Objects.TBitmapLinks) that links to a part of a large image. Custom styles can be defined per platform, which allows the developer to bring the styles closer to the platform's native look. I won't go further into the details, as the [official documentation](https://docwiki.embarcadero.com/RADStudio/Athens/en/Customizing_FireMonkey_Applications_with_Styles) covers it well.

Looking at the currently most popular cross-platform applications, such as [Discord](https://discord.com/), [WhatsApp](https://www.whatsapp.com/), and [Slack](https://slack.com/), all share (almost) the same style across platforms. More applications tend to follow that path, and I am a fan as well: from the designer's standpoint, there is only one style that needs to be worked upon, and from the user's standpoint, I like to have the ability to switch platforms and still feel familiar with the same application. Keep in mind that I'm talking specifically about the application style and not the user interface.

The FMX framework introduces style object classes for defining the bitmap links. Their ancestor class is [`TCustomStyleObject`](https://docwiki.embarcadero.com/Libraries/Athens/en/FMX.Styles.Objects.TCustomStyleObject), which draws a bitmap on the canvas by retreiving the bitmap link from a virtual abstract function _GetCurrentLink_ and getting the actual bitmap from the _Source_, the large image I mentioned above. Every child class defines its own set of bitmap link published properties (e.g. [`TActiveStyleObject`](https://docwiki.embarcadero.com/Libraries/Athens/en/FMX.Styles.Objects.TActiveStyleObject) has _SourceLink_ and _ActiveLink_) that they return in the _GetCurrentLink_ function, depending on which one is active.

What I find troubling with this implementation is the fact that the FMX has set the bitmap links and the image source as the base of their style object classes, and built upon that are the child classes functionalities. It is not possible to define any other link types (such as `TAlphaColor`, or since _skia4delphi_, `TSkSvgBrush`) and implement a custom drawing to the canvas. Because of that, ZX reimplements the style object classes in a way that the functionalities are defined first, and then the child classes can implement the drawing in any way they want.

Additional limitation with the bitmap links is the lack of animations. If you take a look at some the FMX's style objects implementation, you'll see that they actually use the [`TAnimation`](https://docwiki.embarcadero.com/Libraries/Athens/en/FMX.Ani.TAnimation) internally; but not for doing actual animations. `TAnimation`, besides its core functionality, provides two additional properties: _Trigger_ and _TriggerInverse_, which are used to decide when to start the animation ([learn more](https://docwiki.embarcadero.com/RADStudio/Athens/en/FireMonkey_Animation_Effects)). This is what some of the style objects use, while the actual animation is set to never start, only to notify the handler that the trigger has occurred.

### TZxCustomActiveStyleObject
Style object similar to [`TActiveStyleObject`](https://docwiki.embarcadero.com/Libraries/Athens/en/FMX.Styles.Objects.TActiveStyleObject); it contains a published property _ActiveTrigger_ for defining the trigger type. Unlike its counterpart, it contains no implementation for handling the trigger (e.g. drawing a bitmap link). It also contains a public property _Duration_, for setting the animation duration.

#### TZxColorActiveStyleObject
A descendant of `TZxCustomActiveStyleObject` that draws a colored rectangle (fill color only) depending on the trigger state. When the trigger occurs, the color change is animated through interpolation. To set the colors, use the published properties _SourceColor_ and _ActiveColor_. The class also contains _RadiusX_ and _RadiusY_, allowing you to draw a round rectangle.

#### TZxAnimatedImageActiveStyleObject
Thanks to _skia4delphi_, we have the ability to display animated images through [`TSkAnimatedImage`](https://github.com/skia4delphi/skia4delphi/blob/main/Documents/ANIMATED-IMAGES.md). This class implements a `TSkAnimatedImage` whose animation starts when the trigger is executed. There are two possible states, depending on the boolean value of the _AniLoop_ property:
1. If set to false, the animation starts on trigger and starts inversed on inverse trigger, but does not loop, and
2. if set to true, the animation starts on trigger in a loop, and stops on inverse trigger.
There are also additional properties for the image animation: _AniDelay_, _AniSource_, and _AniSpeed_.

### TZxCustomButtonStyleObject
This class implements the functionality of the `TButtonStyleObject` with the button trigger types (_Normal_, _Hot_, _Pressed_, _Focused_), but whose animations have a changeable duration through the published _Duration_ property.

#### TZxColorButtonStyleObject
A descendant of `TZxCustomButtonStyleObject` that draws a colored rectangle (fill color only) depending on the trigger state. When any of the triggers occur, the animation interpolates the previous trigger color and the new trigger color. To set the trigger colors, use the published properties _NormalColor_, _HotColor_, _PressedColor_, or _FocusedColor_. The class also contains _RadiusX_ and _RadiusY_, allowing you to draw a round rectangle.

# Adding default style for components 
While writing these components, I had trouble finding how to define a default style for a component that:
1. doesn't require overriding _GetStyleObject_ method in every class to load the style from resource, and
2. works in both runtime and designtime (without having to open the unit in which the style is defined).

The current [documentation](https://docwiki.embarcadero.com/RADStudio/Alexandria/en/Step_3_-_Add_Style-Resources_as_RCDATA_(Delphi)#Add_the_Style-Resources_as_RCDATA) doesn't satisfy the first request, and for the second one, to get the style to show up in runtime, the style resource has to be added to the application (at least that is the only solution I found). What bothered me is the fact that the FMX controls have their default styles, and they do not load the same way as described in the documentation for custom controls. In pursuit of achieving the same behavior, I realized that the styles are loaded in designtime similar to that in the runtime, except the loading of the [`TStyleBook`](https://docwiki.embarcadero.com/Libraries/Athens/en/FMX.Controls.TStyleBook) component. That gave me the idea to get the designtime's current `TStyleContainer` through [`TStyleManager`](https://docwiki.embarcadero.com/Libraries/Athens/en/FMX.Styles.TStyleManager)'s function `ActiveStyle`, and then add the custom control's default style to its children list. To implement this, ZX provides a `TZxStyleManager` class with the following class methods:
```delphi
class function AddStyles(const ADataModuleClass: TDataModuleClass): IZxStylesHolder; overload;
class function AddStyles(const AStyleContainer: TStyleContainer; const AClone: Boolean): IZxStylesHolder; overload;
class procedure RemoveStyles(const AStylesHodler: IZxStylesHolder);
```

_Note:_ The first _AddStyles_ procedure with the _ADataModuleClass_ parameter internally creates the data module instance, loops through its children and for every `TStyleBook` instance does the same process as the second _AddStyles_ method. 

## Advantages and disadvantages
The benefits of this implementations are:
- no need for data resources,
- no need to override the _GetStyleObject_ method, and
- the styles are always visible, without needing to open the data module unit in which the style is defined.

Caveats to this implementations are yet to be found.

_WARNING:_ this implementation is not thoroughly tested on all platforms, so there is a possibility you may run into bugs or problems when using this approach. It has been tested with only one platform/collection defined, _Default_, as ZX's approach to styles is one-for-all. Feel free to report any issues or suggest improvements!

## How to use
The following are the steps to use the `TZxStyleManager`:
1. Create a `TDataModule` unit, add a `TStyleBook` and define a style in it.
2. Add _Zx.StyleManager_ unit in the implementation _uses_ section.
3. In the implementation section, declare a variable of type `IZxStylesHolder`.
4. In the initialization section, call _TZxStyleManager.AddStyles_ with your data module class as the parameter, and store the return value in the previously declared variable.
5. In the finalization section, call _TZxStyleManager.RemoveStyles_ with the previously declared variable as the parameter.
