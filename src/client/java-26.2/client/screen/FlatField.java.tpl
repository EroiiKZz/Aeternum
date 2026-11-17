package fr.imero.__PKG__.client.screen;

import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.Font;
import net.minecraft.client.gui.GuiGraphicsExtractor;
import net.minecraft.client.gui.components.EditBox;
import net.minecraft.network.chat.Component;

public class FlatField extends EditBox {
	public static final int PADDING = 6;

	private static final int TEXT_HEIGHT = 8;

	private final int boxHeight;
	private boolean invalid;
	private Component placeholder;
	private boolean quiet;

	public FlatField(Font font, int x, int y, int width, int height, Component message) {
		super(font, x + PADDING, y + (height - TEXT_HEIGHT) / 2, Math.max(0, width - PADDING * 2), TEXT_HEIGHT,
			message);
		this.boxHeight = height;
		setBordered(false);
		setTextShadow(false);
	}

	public int boxX() {
		return getX() - PADDING;
	}

	public int boxY() {
		return getY() - textOffset();
	}

	public int boxWidth() {
		return getWidth() + PADDING * 2;
	}

	public int boxHeight() {
		return boxHeight;
	}

	protected int textOffset() {
		return (boxHeight - TEXT_HEIGHT) / 2;
	}

	public void setBox(int x, int y, int width) {
		setX(x + PADDING);
		setY(y + textOffset());
		setWidth(Math.max(0, width - PADDING * 2));
	}

	@Override
	public void setHint(Component hint) {
		placeholder = hint;
	}

	public FlatField quiet(boolean quiet) {
		this.quiet = quiet;
		return this;
	}

	public FlatField invalid(boolean invalid) {
		this.invalid = invalid;
		return this;
	}

	@Override
	public boolean isMouseOver(double mouseX, double mouseY) {
		return visible && mouseX >= boxX() && mouseX < boxX() + boxWidth()
			&& mouseY >= boxY() && mouseY < boxY() + boxHeight;
	}

	@Override
	public void extractWidgetRenderState(GuiGraphicsExtractor context, int mouseX, int mouseY, float delta) {
		int left = boxX();
		int top = boxY();
		int right = left + boxWidth();
		int bottom = top + boxHeight;
		Shape.field(context, left, top, right, bottom, isFocused() && !quiet, invalid);
		if ((quiet || !isFocused()) && !invalid && isMouseOver(mouseX, mouseY)) {
			Shape.stroke(context, left, top, right, bottom, Theme.TILE_RADIUS, 1, Theme.alpha(Theme.TEXT_PRIMARY, 0x30));
		}
		super.extractWidgetRenderState(context, mouseX, mouseY, delta);
		if (placeholder != null && getValue().isEmpty()) {
			Fit.draw(context, Minecraft.getInstance().font, placeholder, getX(), getY(), getWidth() - 4,
				Theme.TEXT_SECONDARY, isMouseOver(mouseX, mouseY) ? mouseX : Integer.MIN_VALUE, mouseY);
		}
	}
}
