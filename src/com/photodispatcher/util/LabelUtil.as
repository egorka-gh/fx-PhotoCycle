package com.photodispatcher.util{
	import flash.text.AntiAliasType;
	import flash.text.Font;
	import flash.text.GridFitType;
	import flash.text.TextLineMetrics;
	import mx.controls.Label;
	import mx.core.Application;
	import mx.core.UITextFormat;
	import mx.styles.CSSStyleDeclaration;
	import mx.styles.StyleManager;
	
	public class LabelUtil{
		
		static public function constrainTextToWidth( label:Label, htmlText:String ):void{
			var style:CSSStyleDeclaration = StyleManager.getStyleDeclaration('.' + label.styleName);
			var fontSize:Number = style.getStyle('fontSize') as Number;
			label.setStyle('fontSize', fontSize );
			label.htmlText= htmlText;
			label.invalidateSize();
			label.validateNow();
			while (getTextWidth( label.text, fontSize, style ) > label.width ){
				fontSize=fontSize – 0.5;
				label.setStyle('fontSize', fontSize );
			}
		}
		
		static public function getTextWidth( text:String, fontSize:Number, style:CSSStyleDeclaration ):Number{
			var textFormat:UITextFormat= new UITextFormat(
				Application.application.systemManager,style.getStyle('fontFamily'),
				fontSize,
				null,
				style.getStyle('fontWeight')=='bold',
				style.getStyle('fontStyle')=='italic',
				null,
				null,
				null,
				null,
				style.getStyle('paddingLeft'),
				style.getStyle('paddingRight'),
				style.getStyle('textIndent'));
			textFormat.antiAliasType= flash.text.AntiAliasType.ADVANCED;
			textFormat.gridFitType= flash.text.GridFitType.PIXEL;
			var textMetrics:TextLineMetrics = textFormat.measureText(text);
			return textMetrics.width;                    
		}
	}
	
}