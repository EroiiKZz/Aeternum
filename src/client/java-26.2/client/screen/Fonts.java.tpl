package fr.imero.__PKG__.client.screen;

import net.minecraft.network.chat.Component;

public final class Fonts {
	private Fonts() {
	}

	public static Component ui(Component text) {
		return text;
	}

	public static Component ui(String text) {
		return Component.literal(text);
	}

	public static Component small(Component text) {
		return text;
	}

	public static Component small(String text) {
		return Component.literal(text);
	}

	public static Component strong(Component text) {
		return text;
	}

	public static Component strong(String text) {
		return Component.literal(text);
	}

	public static Component title(Component text) {
		return text;
	}

	public static Component title(String text) {
		return Component.literal(text);
	}
}
