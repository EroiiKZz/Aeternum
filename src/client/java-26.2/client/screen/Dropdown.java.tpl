package fr.imero.__PKG__.client.screen;

import net.minecraft.client.gui.Font;
import net.minecraft.client.gui.GuiGraphicsExtractor;
import org.lwjgl.glfw.GLFW;

import java.util.ArrayList;
import java.util.List;
import java.util.function.IntConsumer;

public final class Dropdown {
	private static final int MAX_VISIBLE = 10;

	private final List<String> options = new ArrayList<>();
	private IntConsumer sink;
	private boolean open;
	private int selected;
	private int x;
	private int y;
	private int width;
	private int height;
	private int scroll;

	public boolean isOpen() {
		return open;
	}

	public void open(Font font, List<String> labels, int current, int anchorLeft, int anchorRight, int anchorTop,
			int anchorBottom, int screenWidth, int screenHeight, IntConsumer consumer) {
		options.clear();
		options.addAll(labels);
		if (options.isEmpty()) {
			return;
		}
		sink = consumer;
		selected = current;
		int widest = 0;
		for (String option : options) {
			widest = Math.max(widest, font.width(option));
		}
		int maxWidth = Math.max(60, screenWidth - Theme.SPACE_2 * 2);
		width = Math.min(maxWidth, Math.max(anchorRight - anchorLeft, widest + Theme.SPACE_3 * 2));
		int visible = Math.min(options.size(), MAX_VISIBLE);
		height = visible * Theme.ROW_DENSE;
		x = Math.clamp(anchorRight - width, Theme.SPACE_2 + Theme.SPACE_2, Math.max(Theme.SPACE_2 + Theme.SPACE_2, screenWidth - width - Theme.SPACE_2 - Theme.SPACE_2));
		y = anchorBottom + height + Theme.SPACE_2 + Theme.SPACE_2 <= screenHeight ? anchorBottom + Theme.SPACE_2
			: Math.max(Theme.SPACE_2 + Theme.SPACE_2, anchorTop - height - Theme.SPACE_2);
		scroll = Math.clamp(current - visible / 2, 0, Math.max(0, options.size() - visible));
		open = true;
	}

	public void close() {
		open = false;
		sink = null;
	}

	private int visibleCount() {
		return Math.min(options.size(), MAX_VISIBLE);
	}

	private boolean inside(double mouseX, double mouseY) {
		return mouseX >= x && mouseX < x + width && mouseY >= y && mouseY < y + height;
	}

	private int indexAt(double mouseX, double mouseY) {
		if (!inside(mouseX, mouseY)) {
			return -1;
		}
		int index = scroll + (int) ((mouseY - y) / Theme.ROW_DENSE);
		return index < options.size() ? index : -1;
	}

	public void render(GuiGraphicsExtractor context, Font font, int mouseX, int mouseY) {
		if (!open) {
			return;
		}
		Shape.fill(context, x - Theme.SPACE_2, y - Theme.SPACE_2, x + width + Theme.SPACE_2, y + height + Theme.SPACE_2,
			Theme.RADIUS, Theme.opaque(Theme.WINDOW));
		Shape.card(context, x - Theme.SPACE_2, y - Theme.SPACE_2, x + width + Theme.SPACE_2, y + height + Theme.SPACE_2);
		int hovered = indexAt(mouseX, mouseY);
		for (int row = 0; row < visibleCount(); row++) {
			int index = scroll + row;
			int top = y + row * Theme.ROW_DENSE;
			if (index == hovered) {
				Shape.fill(context, x, top, x + width, top + Theme.ROW_DENSE, Theme.TILE_RADIUS, Theme.TILE);
			}
			int color = index == selected || index == hovered ? Theme.ACCENT : Theme.TEXT_PRIMARY;
			context.text(font, Fit.text(font, options.get(index), width - Theme.SPACE_3 * 2), x + Theme.SPACE_3,
				top + (Theme.ROW_DENSE - 8) / 2, color, false);
		}
		if (options.size() > visibleCount()) {
			Panel.scrollbar(context, x + width - Theme.SCROLLBAR_WIDTH - 1, y, height,
				options.size() * Theme.ROW_DENSE, scroll * Theme.ROW_DENSE);
		}
	}

	public boolean mouseClicked(double mouseX, double mouseY, int button) {
		if (!open) {
			return false;
		}
		int index = button == GLFW.GLFW_MOUSE_BUTTON_LEFT ? indexAt(mouseX, mouseY) : -1;
		IntConsumer target = sink;
		close();
		if (index >= 0 && target != null) {
			target.accept(index);
		}
		return true;
	}

	public boolean mouseScrolled(double vertical) {
		if (!open) {
			return false;
		}
		scroll = Math.clamp(scroll - (int) Math.signum(vertical), 0, Math.max(0, options.size() - visibleCount()));
		return true;
	}

	public boolean keyPressed(int keyCode) {
		if (!open) {
			return false;
		}
		if (keyCode == GLFW.GLFW_KEY_ESCAPE) {
			close();
		}
		return true;
	}
}
