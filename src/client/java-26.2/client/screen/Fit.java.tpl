package fr.imero.__PKG__.client.screen;

import net.minecraft.client.gui.Font;
import net.minecraft.client.gui.GuiGraphicsExtractor;
import net.minecraft.locale.Language;
import net.minecraft.network.chat.Component;
import net.minecraft.network.chat.FormattedText;
import net.minecraft.util.FormattedCharSequence;

public final class Fit {
	public static final String ELLIPSIS = "…";

	private static final int TOOLTIP_WIDTH = 240;

	private Fit() {
	}

	public static String text(Font font, String text, int maxWidth) {
		if (text == null || font.width(text) <= maxWidth) {
			return text == null ? "" : text;
		}
		String cut = font.plainSubstrByWidth(text, Math.max(0, maxWidth - font.width(ELLIPSIS))).stripTrailing();
		return cut.isEmpty() ? "" : cut + ELLIPSIS;
	}

	public static FormattedCharSequence line(Font font, Component text, int maxWidth) {
		if (font.width(text) <= maxWidth) {
			return text.getVisualOrderText();
		}
		Component ellipsis = Component.literal(ELLIPSIS).withStyle(text.getStyle());
		FormattedText cut = font.substrByWidth(text, Math.max(0, maxWidth - font.width(ellipsis)));
		return Language.getInstance().getVisualOrder(FormattedText.composite(cut, ellipsis));
	}

	public static boolean cut(Font font, Component text, int maxWidth) {
		return font.width(text) > maxWidth;
	}

	public static void tooltip(GuiGraphicsExtractor context, Font font, Component text, int maxWidth,
			int x0, int y0, int x1, int y1, int mouseX, int mouseY) {
		if (cut(font, text, maxWidth) && mouseX >= x0 && mouseX < x1 && mouseY >= y0 && mouseY < y1) {
			context.setTooltipForNextFrame(font, font.split(text, TOOLTIP_WIDTH), mouseX, mouseY);
		}
	}

	public static int draw(GuiGraphicsExtractor context, Font font, Component text, int x, int y, int maxWidth,
			int color, int mouseX, int mouseY) {
		FormattedCharSequence shown = line(font, text, maxWidth);
		context.text(font, shown, x, y, color, false);
		tooltip(context, font, text, maxWidth, x, y - 1, x + maxWidth, y + 9, mouseX, mouseY);
		return font.width(shown);
	}

	public static void drawCentered(GuiGraphicsExtractor context, Font font, Component text, int x0, int x1, int y,
			int color, int mouseX, int mouseY) {
		int room = Math.max(0, x1 - x0);
		FormattedCharSequence shown = line(font, text, room);
		context.text(font, shown, x0 + (room - font.width(shown)) / 2, y, color, false);
		tooltip(context, font, text, room, x0, y - 1, x1, y + 9, mouseX, mouseY);
	}
}
