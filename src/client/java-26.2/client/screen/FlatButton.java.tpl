package fr.imero.__PKG__.client.screen;

import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.GuiGraphicsExtractor;
import net.minecraft.client.gui.narration.NarrationElementOutput;
import net.minecraft.client.gui.components.AbstractButton;
import net.minecraft.client.input.InputWithModifiers;
import net.minecraft.network.chat.Component;

import java.util.function.Consumer;

public class FlatButton extends AbstractButton {
	public static final Component DONE = Component.translatable("aeternum.config.done");
	public static final Component CANCEL = Component.translatable("aeternum.config.cancel");

	private final Consumer<FlatButton> onPress;

	private boolean primary;

	private boolean alert;

	private boolean shiftHeld;

	public FlatButton(int x, int y, int width, int height, Component message, Consumer<FlatButton> onPress) {
		super(x, y, width, height, message);
		this.onPress = onPress;
	}

	public FlatButton primary() {
		return primary(true);
	}

	public FlatButton primary(boolean on) {
		this.primary = on;
		return this;
	}

	public FlatButton alert() {
		this.alert = true;
		return this;
	}

	public boolean shiftHeld() {
		return shiftHeld;
	}

	@Override
	public void onPress(InputWithModifiers input) {
		shiftHeld = input != null && input.hasShiftDown();
		onPress.accept(this);
	}

	@Override
	protected void extractContents(GuiGraphicsExtractor context, int mouseX, int mouseY, float delta) {
		boolean hot = active && (isHovered() || isFocused());
		boolean accent = primary && active;
		if (accent) {
			Shape.accentButton(context, getX(), getY(), getRight(), getBottom(), hot);
		} else if (alert && active) {
			if (hot) {
				Shape.fill(context, getX(), getY(), getRight(), getBottom(), Theme.TILE_RADIUS, Theme.alpha(Theme.ALERT, 0x24));
			}
			Shape.stroke(context, getX(), getY(), getRight(), getBottom(), Theme.TILE_RADIUS, 1, Theme.alpha(Theme.ALERT, 0x66));
		} else {
			Shape.ghostButton(context, getX(), getY(), getRight(), getBottom(), hot);
		}
		int color = !active ? Theme.TEXT_DISABLED : accent ? Theme.ON_ACCENT
			: alert ? Theme.mix(Theme.ALERT, 0xFFFFFFFF, 0.25) : Theme.TEXT_PRIMARY;
		Minecraft client = Minecraft.getInstance();
		if (client != null) {
			Fit.drawCentered(context, client.font, getMessage(), getX() + Theme.SPACE_2, getRight() - Theme.SPACE_2,
				getY() + (height - 9) / 2 + 1, color, isHovered() ? mouseX : Integer.MIN_VALUE, mouseY);
		}
	}

	@Override
	protected void updateWidgetNarration(NarrationElementOutput builder) {
		defaultButtonNarrationText(builder);
	}
}
