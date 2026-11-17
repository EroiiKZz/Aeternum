package fr.imero.__PKG__.client.screen;

import net.minecraft.client.gui.Font;
import net.minecraft.client.gui.GuiGraphicsExtractor;
import net.minecraft.network.chat.Component;
import net.minecraft.util.FormattedCharSequence;
import org.joml.Matrix3x2fStack;

public enum Type {
	X1(1, Theme.LINE),
	X2(2, Theme.LINE_2),
	X4(4, Theme.LINE_4);

	private static final int GAME_CAP = 7;

	public final int scale;
	public final int line;

	Type(int scale, int line) {
		this.scale = scale;
		this.line = line;
	}

	public int cap() {
		return GAME_CAP * scale;
	}

	public int width(Font renderer, Component text) {
		return renderer.width(text) * scale;
	}

	public void draw(GuiGraphicsExtractor context, Font renderer, Component text, int x, int y, int color) {
		if (scale == 1) {
			context.text(renderer, text, x, y, color, false);
			return;
		}
		Matrix3x2fStack pose = context.pose();
		pose.pushMatrix();
		pose.translate(x, y);
		pose.scale(scale, scale);
		context.text(renderer, text, 0, 0, color, false);
		pose.popMatrix();
	}

	public void draw(GuiGraphicsExtractor context, Font renderer, FormattedCharSequence text, int x, int y, int color) {
		Matrix3x2fStack pose = context.pose();
		pose.pushMatrix();
		pose.translate(x, y);
		pose.scale(scale, scale);
		context.text(renderer, text, 0, 0, color, false);
		pose.popMatrix();
	}

	public void drawMiddle(GuiGraphicsExtractor context, Font renderer, Component text, int x, int middle, int color) {
		draw(context, renderer, text, x, middle - (cap() + 1) / 2, color);
	}
}
