package fr.imero.__PKG__.client.screen;

import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.narration.NarrationMessageBuilder;
import net.minecraft.client.gui.widget.PressableWidget;
import net.minecraft.client.input.AbstractInput;
import net.minecraft.text.Text;

import java.util.function.Consumer;

public class FlatButton extends PressableWidget {
	private final Consumer<FlatButton> onPress;

	private boolean primary;

	private boolean shiftHeld;

	public FlatButton(int x, int y, int width, int height, Text message, Consumer<FlatButton> onPress) {
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

	public boolean shiftHeld() {
		return shiftHeld;
	}

	@Override
	public void onPress(AbstractInput input) {
		shiftHeld = input != null && input.hasShift();
		onPress.accept(this);
	}

	@Override
	protected void renderWidget(DrawContext context, int mouseX, int mouseY, float delta) {
		boolean hot = active && (isHovered() || isFocused());
		context.fill(getX(), getY(), getRight(), getBottom(), hot ? Theme.SURFACE_HOVER : Theme.SURFACE);
		outline(context, hot ? Theme.ACCENT : Theme.BORDER);
		int color = !active ? Theme.TEXT_DISABLED
			: (primary || hot ? Theme.ACCENT : Theme.TEXT_PRIMARY);
		MinecraftClient client = MinecraftClient.getInstance();
		if (client != null) {
			drawScrollableText(context, client.textRenderer, 4, color);
		}
	}

	private void outline(DrawContext context, int color) {
		context.fill(getX(), getY(), getRight(), getY() + 1, color);
		context.fill(getX(), getBottom() - 1, getRight(), getBottom(), color);
		context.fill(getX(), getY(), getX() + 1, getBottom(), color);
		context.fill(getRight() - 1, getY(), getRight(), getBottom(), color);
	}

	@Override
	protected void appendClickableNarrations(NarrationMessageBuilder builder) {
		appendDefaultNarrations(builder);
	}
}
