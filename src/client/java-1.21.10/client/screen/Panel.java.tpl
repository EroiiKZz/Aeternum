package fr.imero.__PKG__.client.screen;

import net.minecraft.client.font.TextRenderer;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.item.ItemStack;
import net.minecraft.text.Text;

public final class Panel {
	private static final int TAB_MIN = 24;
	private static final int TAB_MAX = 72;

	private Panel() {
	}

	public static void backdrop(DrawContext context, int width, int height) {
		context.fill(0, 0, width, height, Theme.BACKDROP);
	}

	public static void frame(DrawContext context, int x, int y, int width, int height) {
		context.fill(x, y, x + width, y + height, Theme.PANEL);
		context.fill(x, y, x + width, y + 1, Theme.BORDER);
		context.fill(x, y + height - 1, x + width, y + height, Theme.BORDER);
		context.fill(x, y, x + 1, y + height, Theme.BORDER);
		context.fill(x + width - 1, y, x + width, y + height, Theme.BORDER);
		int tab = Math.clamp(width / 4, TAB_MIN, Math.min(TAB_MAX, width));
		context.fill(x, y, x + tab, y + Theme.PANEL_RULE, Theme.ACCENT);
	}

	public static void separator(DrawContext context, int panelX, int y, int panelWidth) {
		context.fill(panelX + Theme.PADDING, y, panelX + panelWidth - Theme.PADDING, y + 1,
			Theme.BORDER);
	}

	public static void badge(DrawContext context, ItemStack stack, int x, int panelY) {
		context.drawItem(stack, x, panelY + (Theme.HEADER_HEIGHT - Theme.ICON) / 2);
	}

	public static int titleX(int panelX, int badgeWidth) {
		return panelX + Theme.PADDING + (badgeWidth > 0 ? badgeWidth + Theme.GUTTER : 0);
	}

	public static int headerTextY(int panelY) {
		return panelY + (Theme.HEADER_HEIGHT - 8) / 2;
	}

	public static void masthead(DrawContext context, TextRenderer font, Text title, Text stat,
			int panelX, int panelY, int panelWidth, int badgeWidth) {
		int textY = headerTextY(panelY);
		int right = panelX + panelWidth - Theme.PADDING;
		if (stat != null) {
			right -= font.getWidth(stat);
			context.drawText(font, stat, right, textY, Theme.TEXT_SECONDARY, false);
			right -= Theme.GUTTER;
		}
		int titleX = titleX(panelX, badgeWidth);
		String shown = title.getString();
		while (!shown.isEmpty()
			&& titleX + Wordmark.width(font, shown, Wordmark.TITLE_TRACKING) > right) {
			shown = shown.substring(0, shown.offsetByCodePoints(shown.length(), -1));
		}
		Wordmark.draw(context, font, shown, titleX, textY, Theme.TEXT_PRIMARY,
			Wordmark.TITLE_TRACKING);
	}

	public static void scrollbar(DrawContext context, int x, int trackTop, int trackHeight,
			int contentHeight, double scroll) {
		int max = Math.max(0, contentHeight - trackHeight);
		if (max <= 0 || trackHeight <= 0 || contentHeight <= 0) {
			return;
		}
		context.fill(x, trackTop, x + Theme.SCROLLBAR_WIDTH, trackTop + trackHeight,
			Theme.alpha(Theme.BORDER, 0x80));
		int thumbHeight = Math.max(20, trackHeight * trackHeight / contentHeight);
		int thumbY = trackTop
			+ (int) ((trackHeight - thumbHeight) * (Math.clamp(scroll, 0, max) / max));
		context.fill(x, thumbY + 1, x + Theme.SCROLLBAR_WIDTH, thumbY + thumbHeight - 1,
			Theme.mix(Theme.ACCENT, Theme.PANEL, 0.45));
	}
}
