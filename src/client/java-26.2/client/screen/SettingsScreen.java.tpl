package fr.imero.__PKG__.client.screen;

import com.mojang.blaze3d.platform.InputConstants;
import fr.imero.__PKG__.client.lang.AeternumLanguage;
import fr.imero.__PKG__.theme.AeternumTheme;
import net.fabricmc.loader.api.FabricLoader;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.Font;
import net.minecraft.client.gui.GuiGraphicsExtractor;
import net.minecraft.client.gui.components.AbstractButton;
import net.minecraft.client.gui.components.AbstractSliderButton;
import net.minecraft.client.gui.components.AbstractWidget;
import net.minecraft.client.gui.components.EditBox;
import net.minecraft.client.gui.narration.NarrationElementOutput;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.client.input.CharacterEvent;
import net.minecraft.client.input.InputWithModifiers;
import net.minecraft.client.input.KeyEvent;
import net.minecraft.client.input.MouseButtonEvent;
import net.minecraft.client.renderer.RenderPipelines;
import net.minecraft.client.resources.language.I18n;
import net.minecraft.locale.Language;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.Identifier;
import net.minecraft.util.FormattedCharSequence;
import net.minecraft.world.item.Item;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.DoubleConsumer;
import java.util.function.DoubleSupplier;
import java.util.function.Function;
import java.util.function.IntConsumer;
import java.util.function.IntFunction;
import java.util.function.IntSupplier;
import java.util.function.Supplier;
import java.util.function.UnaryOperator;

public abstract class SettingsScreen extends Screen {
	protected static final String MOD = "__PKG__";

	private static final int PANEL_MIN_WIDTH = 300;
	private static final int PANEL_MIN_HEIGHT = 220;

	private static final double SIDEBAR_FRACTION = 0.2;
	private static final int SIDEBAR_MIN = 118;
	private static final int LOGO = 22;
	private static final int CHEVRON = 7;
	private static final Identifier CHEVRON_DOWN = Identifier.fromNamespaceAndPath("aeternum",
		"textures/gui/icon/chevron_down.png");
	private static final Identifier CHEVRON_RIGHT = Identifier.fromNamespaceAndPath("aeternum",
		"textures/gui/icon/chevron_right.png");

	private static final double PREVIEW_FRACTION = 0.55;
	private static final int PREVIEW_MAX = 170;

	private static final int READABLE_WIDTH = 470;
	private static final int WIDE_READABLE_WIDTH = 560;
	private static final int CONTROL_WIDTH = 110;
	private static final int SLIDER_TRACK = 130;
	private static final int SLIDER_VALUE = 34;

	protected static final int TOOLTIP_WIDTH = 230;
	private static final int SAMPLE_BAR_WIDTH = 9;
	private static final int SAMPLE_BAR_HEIGHT = 3;

	private static final BooleanSupplier ALWAYS = () -> true;

	private static final String THEME_SECTION = "aeternum.config.section.theme";
	private static final String STYLE_OWNER = "vernis";
	private static final String STYLE_PAGE = "vernis.config.section.style";
	private static final String PAGE_REQUEST = "aeternum.settings.page";
	private static final int[] ACCENTS = {0xD8FF63, 0xF2B441, 0x5FD4E8, 0xB98CFF, 0xFF7567};

	protected final Screen parent;

	private record Requirement(BooleanSupplier gate, String labelKey) {
	}

	protected interface Placeable {
		void place(int x, int width);
	}

	protected static final class Row {
		final String key;
		final AbstractWidget widget;
		final String haystack;
		final List<Requirement> requirements = new ArrayList<>();
		BooleanSupplier enabled = ALWAYS;
		boolean folded;
		boolean wide;
		boolean stacked;
		int baseHeight;
		Component disabledOverride;
		int virtualY;
		int slotX;
		int slotWidth;
		int slotHeight;
		int screenY;
		boolean heading;
		boolean hidden;
		List<FormattedCharSequence> tip = List.of();
		boolean shown = true;

		Row(String key, AbstractWidget widget, String haystack) {
			this.key = key;
			this.widget = widget;
			this.haystack = haystack;
		}

		boolean active() {
			if (!enabled.getAsBoolean()) {
				return false;
			}
			for (Requirement requirement : requirements) {
				if (!requirement.gate().getAsBoolean()) {
					return false;
				}
			}
			return true;
		}

		boolean canBeDisabled() {
			return enabled != ALWAYS || !requirements.isEmpty();
		}

		Component disabledText() {
			for (Requirement requirement : requirements) {
				if (!requirement.gate().getAsBoolean()) {
					return Component.translatable("aeternum.config.requires",
						Component.translatable(requirement.labelKey()));
				}
			}
			return disabledOverride != null ? disabledOverride : Component.translatable("aeternum.config.disabled");
		}

		public AbstractWidget widget() {
			return widget;
		}
	}

	private record Section(String key, int virtualY, int count) {
	}

	private enum SideKind {
		APPEARANCE,
		LANGUAGE,
		CAPTION,
		MOD
	}

	private record SideEntry(SideKind kind, String key, String label, String value, int virtualY, int height,
			boolean current) {
	}

	private record Tab(String key, boolean group, Component label, int x, int y, int width, boolean current) {
	}

	private static final Map<String, String> PAGES = new java.util.HashMap<>();
	private static final int SCROLLBAR_HIT = 8;

	private boolean draggingScrollbar;

	protected interface TooltipSource {
		List<FormattedCharSequence> tooltip(Font font);
	}

	protected record Declared(Row row) {
		public Declared dependsOn(BooleanSupplier gate) {
			row.enabled = gate;
			return this;
		}

		public Declared requires(String labelKey, BooleanSupplier gate) {
			row.requirements.add(new Requirement(gate, labelKey));
			return this;
		}

		public Declared disabledSays(String key) {
			row.disabledOverride = Component.translatable(key);
			return this;
		}

		public Declared wide() {
			row.wide = true;
			return this;
		}

		public Declared themed() {
			row.hidden = AeternumTheme.globalLook();
			return this;
		}
	}

	private final Map<String, List<Row>> sections = new LinkedHashMap<>();
	private final Map<String, Component> sectionLabels = new LinkedHashMap<>();
	private final Map<String, String> sectionGroups = new LinkedHashMap<>();
	private final Map<String, Component> groupLabels = new LinkedHashMap<>();
	private final List<Row> allRows = new ArrayList<>();
	private final List<Section> visibleSections = new ArrayList<>();
	private final List<SideEntry> sideEntries = new ArrayList<>();
	private final List<Tab> tabs = new ArrayList<>();

	private String currentSection;
	private String currentGroup;
	private String currentPage;
	private int contentHeight;
	protected double scroll;
	private double sideScroll;
	private int sideHeight;
	private int headerBottom;
	private boolean revealCurrent;

	protected EditBox filterField;
	protected String filterText = "";
	private String status = "";

	protected final ColorPicker picker = new ColorPicker();
	protected final Dropdown dropdown = new Dropdown();

	protected int panelX;
	protected int panelY;
	protected int panelWidth;
	protected int panelHeight;
	private int sidebarWidth;
	private int mainLeft;
	private int mainRight;
	private int centerLeft;
	private int centerWidth;
	private int columnWidth;
	private boolean asideShown;
	private FlatButton resetLook;
	private FlatButton doneLook;
	private FlatButton footerDone;

	protected SettingsScreen(Screen parent, Component title, Item badge) {
		super(title);
		this.parent = parent;
	}

	protected abstract void buildRows(int x, int w);

	protected abstract void save();

	protected boolean showsThemeSection() {
		return true;
	}

	protected boolean showsSuite() {
		return true;
	}

	protected boolean ownsStyle() {
		return false;
	}

	protected void themeRows(int x, int w) {
	}

	protected void onThemeChanged() {
	}

	protected void footerButtons(int x, int y, int doneX) {
	}

	protected void renderBehindPanel(GuiGraphicsExtractor context, int mouseX, int mouseY) {
	}

	protected boolean hasPreview() {
		return false;
	}

	protected void renderPreview(GuiGraphicsExtractor context, int x, int y, int width, int height, int mouseX,
			int mouseY) {
	}

	protected int previewHeight(int available) {
		return Math.min(PREVIEW_MAX, (int) (available * PREVIEW_FRACTION));
	}

	protected Component hint() {
		String key = MOD + ".config.hint";
		return Language.getInstance().has(key) ? Component.translatable(key) : null;
	}

	protected int headerSeparatorY() {
		return headerBottom;
	}

	private int bodyTop() {
		return panelY + Theme.SPACE_5;
	}

	protected int contentTop() {
		return headerSeparatorY() + Theme.SPACE_3;
	}

	protected int footerTop() {
		return panelY + panelHeight - Theme.FOOTER_HEIGHT - Theme.SPACE_3;
	}

	protected int footerSeparatorY() {
		return footerTop() - 1;
	}

	protected int contentBottom() {
		return footerSeparatorY();
	}

	protected int contentViewHeight() {
		return contentBottom() - contentTop();
	}

	protected int maxScroll() {
		return Math.max(0, contentHeight - contentViewHeight());
	}

	protected boolean inContentBand(double mouseY) {
		return mouseY >= contentTop() && mouseY < contentBottom();
	}

	private int sidebarRight() {
		return panelX + sidebarWidth;
	}

	private int asideLeft() {
		return panelX + panelWidth - Theme.SPACE_5 - Theme.ASIDE;
	}

	private int centerRight() {
		return centerLeft + columnWidth;
	}

	private int searchTop() {
		return bodyTop() + LOGO + Theme.SPACE_5;
	}

	private int sideListTop() {
		return searchTop() + Theme.FIELD_HEIGHT + Theme.SPACE_3;
	}

	private int sideListBottom() {
		return panelY + panelHeight - Theme.SPACE_4;
	}

	private boolean themePage() {
		return !filtering() && THEME_SECTION.equals(currentPage);
	}

	@Override
	protected void init() {
		Theme.sync();
		picker.close();
		dropdown.close();
		sections.clear();
		sectionLabels.clear();
		sectionGroups.clear();
		groupLabels.clear();
		currentGroup = null;
		allRows.clear();
		visibleSections.clear();

		panelWidth = Math.clamp(width - Theme.SPACE_5 * 2, PANEL_MIN_WIDTH, Theme.WIDE);
		panelHeight = Math.clamp(height - Theme.SPACE_5 * 2, PANEL_MIN_HEIGHT, Theme.WIDE_HEIGHT);
		panelX = (width - panelWidth) / 2;
		panelY = (height - panelHeight) / 2;
		sidebarWidth = Math.clamp((int) (panelWidth * SIDEBAR_FRACTION), SIDEBAR_MIN, Theme.NAV);
		mainLeft = sidebarRight() + 1 + Theme.SPACE_6;
		headerBottom = panelY + Theme.SPACE_5 + (Theme.LINE_2 + Theme.SPACE_2) + Theme.ROW_DENSE;
		layoutColumns(hasPreview());

		filterField = new FlatField(font, panelX + Theme.SPACE_4, searchTop(), sidebarWidth - Theme.SPACE_4 * 2,
			Theme.FIELD_HEIGHT, Component.translatable("aeternum.config.search"));
		filterField.setHint(Fonts.ui(Component.translatable("aeternum.config.search"))
			.copy().withStyle(s -> s.withColor(Theme.rgb(Theme.TEXT_SECONDARY))));
		filterField.setValue(filterText);
		((FlatField) filterField).quiet(true);
		filterField.setResponder(text -> {
			filterText = text;
			scroll = 0;
			applyFilter();
		});
		addRenderableWidget(filterField);
		setInitialFocus(filterField);

		int x = centerLeft;
		int w = columnWidth;
		buildRows(x, w);
		endGroup();
		if (showsThemeSection()) {
			buildThemeSection(x, w);
		}

		int buttonY = footerTop() + (Theme.FOOTER_HEIGHT - Theme.BUTTON_HEIGHT) / 2;
		int doneX = panelX + panelWidth - Theme.SPACE_6 - Theme.FOOTER_BUTTON_WIDTH;
		footerButtons(mainLeft, buttonY, doneX);
		footerDone = addRenderableWidget(new FlatButton(doneX, buttonY, Theme.FOOTER_BUTTON_WIDTH,
			Theme.BUTTON_HEIGHT, FlatButton.DONE, b -> onClose()).primary());

		consumePageRequest();
		currentPage = PAGES.get(getClass().getName());
		revealCurrent = true;
		applyFilter();
	}

	private void layoutColumns(boolean aside) {
		asideShown = aside && panelWidth >= Theme.NAV + 260 + Theme.ASIDE;
		mainRight = (asideShown ? asideLeft() - Theme.SPACE_5 : panelX + panelWidth - Theme.SPACE_6);
		centerLeft = mainLeft;
		centerWidth = mainRight - Theme.SCROLLBAR_WIDTH - Theme.SPACE_3 - centerLeft;
		columnWidth = Math.min(centerWidth, asideShown ? READABLE_WIDTH : WIDE_READABLE_WIDTH);
	}

	@Override
	protected void setInitialFocus() {
		if (filterField != null) {
			setInitialFocus(filterField);
			filterField.moveCursorToEnd(false);
		}
	}

	private void buildThemeSection(int x, int w) {
		section(THEME_SECTION, Component.translatable("aeternum.config.page.appearance"));
		heading("aeternum.config.heading.theme");
		add("aeternum.config.themes", new ThemeCards(x, w));
		List<AeternumTheme.Saved> saved = AeternumTheme.saved();
		if (!saved.isEmpty()) {
			List<String> names = saved.stream().map(AeternumTheme.Saved::name).toList();
			dropdown(x, w, "aeternum.config.saved_theme", () -> names,
				() -> names.indexOf(AeternumTheme.activeSaved()), index -> {
					AeternumTheme.selectSaved(names.get(index));
					restyle(s -> s.withAccent(AeternumTheme.Style.THEME_ACCENT));
					onThemeChanged();
				});
		}
		heading("aeternum.config.heading.colors");
		add("aeternum.config.accent", new AccentRow(x, w));
		heading("aeternum.config.heading.shape");
		int[] radii = AeternumTheme.Style.RADII;
		segments(x, w, "aeternum.config.rounding", List.of("0", "3", "6", "9"), () -> {
			int nearest = AeternumTheme.style().nearestRadius();
			for (int i = 0; i < radii.length; i++) {
				if (radii[i] == nearest) {
					return i;
				}
			}
			return 0;
		}, index -> restyle(s -> s.withRadius(radii[index])));
		AeternumTheme.Depth[] depths = AeternumTheme.Depth.values();
		segments(x, w, "aeternum.config.depth", labels(depths, AeternumTheme.Depth::translationKey),
			() -> AeternumTheme.style().depth().ordinal(), index -> restyle(s -> s.withDepth(depths[index])));
		AeternumTheme.Density[] densities = AeternumTheme.Density.values();
		segments(x, w, "aeternum.config.density", labels(densities, AeternumTheme.Density::translationKey),
			() -> AeternumTheme.style().density().ordinal(), index -> {
				restyle(s -> s.withDensity(densities[index]));
				refresh();
			});
		if (!ownsStyle() && lookOwnerReachable()) {
			action(x, w, "aeternum.config.style_link", () -> openSuitePage(STYLE_OWNER, STYLE_PAGE));
		}
		themeRows(x, w);
		resetLook = addRenderableWidget(new FlatButton(0, 0, 10, Theme.CONTROL_LARGE,
			Component.translatable("aeternum.config.look_reset"), b -> {
				AeternumTheme.select(AeternumTheme.Preset.DEFAULT);
				AeternumTheme.resetStyle();
				Theme.sync();
				onThemeChanged();
				refresh();
			}));
		doneLook = addRenderableWidget(new FlatButton(0, 0, 10, Theme.CONTROL_LARGE, FlatButton.DONE,
			b -> onClose()).primary());
	}

	private static <T> List<String> labels(T[] values, Function<T, String> key) {
		List<String> out = new ArrayList<>();
		for (T value : values) {
			out.add(I18n.get(key.apply(value)));
		}
		return out;
	}

	private static boolean lookOwnerReachable() {
		return AeternumTheme.globalLook()
			&& SuiteLinks.members().stream().anyMatch(member -> member.id().equals(STYLE_OWNER));
	}

	protected final void themeNotice(int x, int w) {
	}

	private void consumePageRequest() {
		String request = System.getProperty(PAGE_REQUEST);
		if (request != null && request.startsWith(MOD + ":")) {
			System.clearProperty(PAGE_REQUEST);
			PAGES.put(getClass().getName(), request.substring(MOD.length() + 1));
		}
	}

	protected final void openSuitePage(String id, String page) {
		if (minecraft == null) {
			return;
		}
		save();
		System.setProperty(PAGE_REQUEST, id + ":" + page);
		Screen target = SuiteLinks.open(id, parent);
		if (target == parent) {
			System.clearProperty(PAGE_REQUEST);
		}
		minecraft.setScreenAndShow(target);
	}

	protected final void styleRows(int x, int w) {
		heading("aeternum.config.heading.shape");
		slider(x, w, "aeternum.config.radius", 0, AeternumTheme.Style.RADIUS_MAX,
			() -> AeternumTheme.style().radius(), v -> restyle(s -> s.withRadius((int) v)),
			v -> v == 0 ? I18n.get("aeternum.config.radius.square") : unit(v, "aeternum.unit.px"));
		toggle(x, w, "aeternum.config.round_hud", AeternumTheme.style().roundHud(),
			v -> restyle(s -> s.withRoundHud(v)))
			.requires("aeternum.config.radius", () -> AeternumTheme.style().radius() > 0);
		slider(x, w, "aeternum.config.stroke", 0, AeternumTheme.Style.STROKE_MAX,
			() -> AeternumTheme.style().stroke(), v -> restyle(s -> s.withStroke((int) v)),
			v -> v == 0 ? I18n.get("aeternum.config.stroke.none") : unit(v, "aeternum.unit.px"));
		choice(x, w, "aeternum.config.rule", () -> AeternumTheme.style().rule().translationKey(),
			() -> restyle(s -> s.withRule(s.rule().next())));
		choice(x, w, "aeternum.config.shadow", () -> AeternumTheme.style().shadow().translationKey(),
			() -> restyle(s -> s.withShadow(s.shadow().next())));
		heading("aeternum.config.heading.layout");
		choice(x, w, "aeternum.config.selection", () -> AeternumTheme.style().selection().translationKey(),
			() -> restyle(s -> s.withSelection(s.selection().next())));
		heading("aeternum.config.heading.legibility");
		choice(x, w, "aeternum.config.text_shadow", () -> AeternumTheme.style().textShadow().translationKey(),
			() -> restyle(s -> s.withTextShadow(s.textShadow().next())));
		slider(x, w, "aeternum.config.contrast", 0, AeternumTheme.Style.CONTRAST_MAX,
			() -> AeternumTheme.style().contrast(), v -> restyle(s -> s.withContrast((int) v)), v -> v + " %");
		heading("aeternum.config.heading.transparency");
		slider(x, w, "aeternum.config.backdrop", 0, AeternumTheme.Style.BACKDROP_MAX,
			() -> AeternumTheme.style().backdrop(), v -> restyle(s -> s.withBackdrop((int) v)), v -> v + " %");
		slider(x, w, "aeternum.config.panel", AeternumTheme.Style.PANEL_MIN, AeternumTheme.Style.PANEL_MAX,
			() -> AeternumTheme.style().panel(), v -> restyle(s -> s.withPanel((int) v)), v -> v + " %");
		action(x, w, "aeternum.config.style_reset", () -> {
			AeternumTheme.resetStyle();
			Theme.sync();
			refresh();
		});
	}

	private static void restyle(UnaryOperator<AeternumTheme.Style> change) {
		AeternumTheme.setStyle(change.apply(AeternumTheme.style()));
		Theme.sync();
	}

	public static String themeName() {
		String saved = AeternumTheme.activeSaved();
		return saved != null ? saved : I18n.get(AeternumTheme.preset().translationKey());
	}

	protected final void refresh() {
		double keep = scroll;
		rebuildWidgets();
		scroll = Math.clamp(keep, 0, maxScroll());
		position();
	}

	protected final void section(String key) {
		section(key, Component.translatable(key));
	}

	protected final void section(String id, Component label) {
		currentSection = id;
		sections.computeIfAbsent(id, k -> new ArrayList<>());
		sectionLabels.putIfAbsent(id, label);
		if (currentGroup != null) {
			sectionGroups.putIfAbsent(id, currentGroup);
		}
	}

	protected final void group(String key) {
		group(key, Component.translatable(key));
	}

	protected final void group(String id, Component label) {
		currentGroup = id;
		groupLabels.putIfAbsent(id, label);
	}

	protected final void endGroup() {
		currentGroup = null;
	}

	private String pageLabel(String key) {
		String group = sectionGroups.get(key);
		String label = sectionLabels.get(key).getString();
		return group == null ? label : groupLabels.get(group).getString() + " · " + label;
	}

	protected final Declared add(String key, AbstractWidget widget) {
		return add(key, widget, "");
	}

	protected final Declared add(String key, AbstractWidget widget, String extraSearch) {
		String tipKey = key + ".tip";
		String haystack = (widget.getMessage().getString() + " " + I18n.get(key) + " "
			+ pageLabel(currentSection) + " "
			+ (Language.getInstance().has(tipKey) ? I18n.get(tipKey) : "") + " " + extraSearch)
			.toLowerCase(Locale.ROOT);
		Row row = new Row(key, widget, haystack);
		row.wide = widget instanceof TextRow || widget instanceof NoticeRow;
		row.baseHeight = widget instanceof TextRow ? Theme.SETTING_ROW_HEIGHT : widget.getHeight();
		row.stacked = widget instanceof SettingButton button ? button.stackable : widget instanceof SliderRow;
		sections.get(currentSection).add(row);
		allRows.add(row);
		addWidget(widget);
		return new Declared(row);
	}

	protected final void heading(String key) {
		heading(key, Component.translatable(key));
	}

	protected final void heading(String id, Component label) {
		Row row = new Row(id, new HeadingRow(label), "");
		row.heading = true;
		row.baseHeight = (Theme.LINE + Theme.SPACE_5);
		sections.get(currentSection).add(row);
		allRows.add(row);
	}

	protected final Declared toggle(int x, int w, String key, boolean initial, Consumer<Boolean> setter) {
		return add(key, new ToggleRow(x, w, Component.translatable(key), initial, setter));
	}

	protected final Declared slider(int x, int w, String key, int min, int max,
			DoubleSupplier getter, DoubleConsumer setter, IntFunction<String> format) {
		return add(key, new SliderRow(x, w, key, min, max, getter, setter, format));
	}

	protected final Declared choice(int x, int w, String key, Supplier<String> valueKey, Runnable cycle) {
		return add(key, new ChoiceRow(x, w, Component.translatable(key), valueKey, cycle));
	}

	protected final Declared choiceText(int x, int w, String key, Supplier<String> shown, Runnable cycle) {
		return add(key, new ChoiceRow(x, w, Component.translatable(key), shown, cycle, false));
	}

	protected final Declared text(int x, int w, String key, String value, Consumer<String> setter,
			Function<String, String> validator) {
		return add(key, new TextRow(x, w, Component.translatable(key), value, setter, validator), value);
	}

	protected final Declared dropdown(int x, int w, String key, Supplier<List<String>> labels, IntSupplier selected,
			IntConsumer select) {
		return add(key, new DropdownRow(x, w, Component.translatable(key), labels, selected, select));
	}

	protected final Declared segments(int x, int w, String key, List<String> labels, IntSupplier selected,
			IntConsumer select) {
		return add(key, new SegmentRow(x, w, Component.translatable(key), labels, selected, select),
			String.join(" ", labels));
	}

	public final void openDropdown(AbstractWidget anchor, List<String> labels, int selected, IntConsumer sink) {
		dropdown.open(font, labels, selected, anchor.getX(), anchor.getRight(), anchor.getY(), anchor.getBottom(),
			width, height, sink);
	}

	protected final Declared action(int x, int w, String key, Runnable onPress) {
		return add(key, new ActionRow(x, w, Component.translatable(key), b -> onPress.run()));
	}

	protected final Declared color(int x, int w, String key, IntSupplier getter, IntConsumer setter) {
		return add(key, new ColorRow(x, w, Component.translatable(key), getter, setter));
	}

	protected final Declared hexColor(int x, int w, String key, Supplier<String> getter,
			Consumer<String> setter) {
		return color(x, w, key, () -> AeternumTheme.parse(getter.get(), 0),
			rgb -> setter.accept(AeternumTheme.hex(rgb)));
	}

	protected static String unit(int value, String key) {
		return value + " " + I18n.get(key);
	}

	public final void openPicker(Component label, int rgb, AbstractWidget anchor, IntConsumer sink) {
		AeternumTheme.Palette palette = AeternumTheme.palette();
		List<Integer> quick = new ArrayList<>();
		for (AeternumTheme.Role role : AeternumTheme.Role.values()) {
			quick.add(palette.role(role));
		}
		picker.open(label, rgb, anchor.getRight() - ColorPicker.WIDTH,
			anchor.getY() + Math.min(anchor.getHeight(), Theme.SETTING_ROW_HEIGHT), width, height, quick, sink);
	}

	private void applyFilter() {
		String query = filterText.trim().toLowerCase(Locale.ROOT);
		for (Row row : allRows) {
			row.shown = !row.hidden
				&& (row.heading ? query.isEmpty() : query.isEmpty() || row.haystack.contains(query));
		}
		relayout();
	}

	private boolean filtering() {
		return !filterText.trim().isEmpty();
	}

	protected final void openSection(String section, boolean open) {
		if (open) {
			PAGES.put(getClass().getName(), section);
			currentPage = section;
		}
	}

	private String firstPage() {
		for (Map.Entry<String, List<Row>> entry : sections.entrySet()) {
			if (!entry.getValue().isEmpty() && !THEME_SECTION.equals(entry.getKey())) {
				return entry.getKey();
			}
		}
		return sections.containsKey(THEME_SECTION) ? THEME_SECTION : null;
	}

	private void selectPage(String key) {
		openSection(key, true);
		if (filtering()) {
			filterText = "";
			filterField.setValue("");
		}
		scroll = 0;
		applyFilter();
	}

	private void relayout() {
		visibleSections.clear();
		if (currentPage == null || !sections.containsKey(currentPage) || sections.get(currentPage).isEmpty()) {
			currentPage = firstPage();
		}
		layoutColumns(hasPreview() || themePage());
		rebuildTabs();
		int y = 0;
		for (Map.Entry<String, List<Row>> entry : sections.entrySet()) {
			boolean onPage = filtering() || entry.getKey().equals(currentPage);
			List<Row> kept = new ArrayList<>();
			for (Row row : entry.getValue()) {
				row.folded = !onPage;
				if (onPage && row.shown) {
					kept.add(row);
				}
			}
			if (kept.isEmpty()) {
				continue;
			}
			if (filtering()) {
				if (!visibleSections.isEmpty()) {
					y += Theme.SETTING_SECTION_GAP;
				}
				visibleSections.add(new Section(entry.getKey(), y, kept.size()));
				y += (Theme.LINE + Theme.SPACE_5);
			} else {
				visibleSections.add(new Section(entry.getKey(), y, kept.size()));
			}
			for (Row row : kept) {
				row.tip = tipLines(row);
				int height = rowHeight(row);
				slot(row, centerLeft, columnWidth, y, height);
				if (row.stacked) {
					row.widget.setHeight(height - Theme.SPACE_1);
					if (row.widget instanceof SettingButton button) {
						button.labelTop = descriptionLines(row) > 0 ? rowPadding() : -1;
					} else if (row.widget instanceof SliderRow slider) {
						slider.labelTop = descriptionLines(row) > 0 ? rowPadding() : -1;
					}
				}
				y += height;
			}
		}
		contentHeight = y + Theme.PADDING;
		scroll = Math.clamp(scroll, 0, maxScroll());
		rebuildSidebar();
		placeLookButtons();
		position();
	}

	private void placeLookButtons() {
		if (resetLook == null) {
			return;
		}
		boolean shown = themePage() && asideShown;
		if (footerDone != null) {
			footerDone.visible = !shown;
		}
		int left = asideLeft();
		int half = (Theme.ASIDE - Theme.GUTTER) / 2;
		int y = previewTop() + lookPreviewHeight() + 10;
		resetLook.visible = shown;
		doneLook.visible = shown;
		resetLook.setRectangle(half, Theme.CONTROL_LARGE, left, y);
		doneLook.setRectangle(Theme.ASIDE - half - Theme.GUTTER, Theme.CONTROL_LARGE, left + half + Theme.GUTTER, y);
	}

	private void rebuildTabs() {
		tabs.clear();
		int x = centerLeft;
		int y = panelY + Theme.SPACE_5 + (Theme.LINE_2 + Theme.SPACE_2) + (subtitle() != null ? (Theme.LINE + Theme.SPACE_2) : 0);
		boolean any = false;
		if (!themePage() && !filtering()) {
			String openGroup = currentPage == null ? null : sectionGroups.get(currentPage);
			List<String> seenGroups = new ArrayList<>();
			int right = mainRight;
			int[] cursor = {x, y};
			for (Map.Entry<String, List<Row>> entry : sections.entrySet()) {
				String key = entry.getKey();
				if (entry.getValue().isEmpty() || THEME_SECTION.equals(key)) {
					continue;
				}
				String group = sectionGroups.get(key);
				if (group == null) {
					addTab(cursor, x, right, key, false, sectionLabels.get(key), key.equals(currentPage));
				} else if (!seenGroups.contains(group)) {
					seenGroups.add(group);
					addTab(cursor, x, right, group, true, groupLabels.get(group), group.equals(openGroup));
				}
			}
			if (!tabs.isEmpty()) {
				any = true;
				cursor[1] += Theme.ROW_DENSE + Theme.SPACE_1;
				cursor[0] = x;
			}
			if (openGroup != null) {
				int before = tabs.size();
				for (Map.Entry<String, List<Row>> entry : sections.entrySet()) {
					if (!entry.getValue().isEmpty() && openGroup.equals(sectionGroups.get(entry.getKey()))) {
						addTab(cursor, x, right, entry.getKey(), false, sectionLabels.get(entry.getKey()),
							entry.getKey().equals(currentPage));
					}
				}
				if (tabs.size() > before) {
					cursor[1] += Theme.ROW_DENSE + Theme.SPACE_1;
				}
			}
			y = cursor[1] - (any ? Theme.SPACE_1 : 0);
		}
		headerBottom = Math.max(y, panelY + Theme.SPACE_5 + (Theme.LINE_2 + Theme.SPACE_2));
	}

	private void addTab(int[] cursor, int left, int right, String key, boolean group, Component label,
			boolean current) {
		Component shown = Fonts.ui(label);
		int w = font.width(shown) + Theme.SPACE_4 * 2;
		if (cursor[0] > left && cursor[0] + w + Shape.SEGMENT_PAD * 2 > right) {
			cursor[0] = left;
			cursor[1] += Theme.ROW_DENSE + Theme.SPACE_1;
		}
		tabs.add(new Tab(key, group, shown, cursor[0] + Shape.SEGMENT_PAD, cursor[1], w, current));
		cursor[0] += w + Shape.SEGMENT_GAP;
	}

	private Component subtitle() {
		if (themePage()) {
			return Component.translatable("aeternum.config.page.appearance.subtitle", suiteSize());
		}
		String key = MOD + ".config.subtitle";
		return Language.getInstance().has(key) ? Component.translatable(key) : null;
	}

	private static int suiteSize() {
		return Math.max(1, SuiteLinks.members().size());
	}

	private static void slot(Row row, int x, int width, int y, int height) {
		row.slotX = x;
		row.slotWidth = width;
		row.virtualY = y;
		row.slotHeight = height;
	}

	private int descriptionWidth(Row row) {
		if (!row.stacked) {
			return columnWidth;
		}
		int control = row.widget instanceof SettingButton button ? button.controlWidth()
			: row.widget instanceof SliderRow slider ? slider.controlWidth() : SLIDER_TRACK + SLIDER_VALUE + 8;
		return Math.max(80, columnWidth - control - Theme.GUTTER * 2);
	}

	private List<FormattedCharSequence> tipLines(Row row) {
		String tipKey = row.key + ".tip";
		if (row.heading || row.widget instanceof TooltipSource || !Language.getInstance().has(tipKey)) {
			return List.of();
		}
		return font.split(Fonts.small(Component.translatable(tipKey)), descriptionWidth(row));
	}

	private static int descriptionLines(Row row) {
		return Math.max(row.tip.size(), row.canBeDisabled() ? 1 : 0);
	}

	private static int rowPadding() {
		return Math.max(3, (Theme.SETTING_ROW_HEIGHT - 14) / 2);
	}

	private static int rowHeight(Row row) {
		if (row.heading) {
			return (Theme.LINE + Theme.SPACE_5);
		}
		int lines = descriptionLines(row);
		if (row.stacked) {
			int text = (Theme.LINE + Theme.SPACE_1) + lines * Theme.LINE;
			return Math.max(Theme.SETTING_ROW_HEIGHT, text + rowPadding() * 2) + Theme.SPACE_1;
		}
		return row.baseHeight + (lines > 0 ? 2 + lines * Theme.LINE : 0) + Theme.SPACE_1 + 4;
	}

	private void drawDescription(GuiGraphicsExtractor context, Row row) {
		int lines = descriptionLines(row);
		if (row.heading || lines == 0) {
			return;
		}
		List<FormattedCharSequence> shown;
		int color;
		if (!row.widget.active && row.canBeDisabled()) {
			shown = font.split(Fonts.small(row.disabledText()), descriptionWidth(row));
			color = Theme.TEXT_STALE;
		} else {
			shown = row.tip;
			color = row.widget.active ? Theme.TEXT_SECONDARY : Theme.TEXT_DISABLED;
		}
		int y = row.stacked ? row.screenY + rowPadding() + (Theme.LINE + Theme.SPACE_1) : row.screenY + row.baseHeight + 2;
		for (int i = 0; i < Math.min(lines, shown.size()); i++) {
			context.text(font, shown.get(i), row.slotX, y + i * Theme.LINE, color, false);
		}
	}

	protected final void position() {
		int top = contentTop();
		int bottom = contentBottom();
		for (Row row : allRows) {
			if (!row.shown || row.folded) {
				row.widget.visible = false;
				continue;
			}
			if (row.widget instanceof Placeable placeable) {
				placeable.place(row.slotX, row.slotWidth);
			} else {
				if (row.widget.getX() != row.slotX) {
					row.widget.setX(row.slotX);
				}
				if (row.widget.getWidth() != row.slotWidth) {
					row.widget.setWidth(row.slotWidth);
				}
			}
			int screenY = top + row.virtualY - (int) scroll;
			row.screenY = screenY;
			row.widget.setY(screenY);
			row.widget.visible = screenY + row.slotHeight > top && screenY < bottom;
		}
	}

	protected final void scrollTo(String sectionKey) {
		selectPage(sectionKey);
	}

	private void rebuildSidebar() {
		sideEntries.clear();
		int y = 0;
		if (showsThemeSection()) {
			sideEntries.add(new SideEntry(SideKind.APPEARANCE, THEME_SECTION,
				I18n.get("aeternum.config.page.appearance"), null, y, Theme.ROW_DENSE, themePage()));
			y += Theme.ROW_DENSE;
			sideEntries.add(new SideEntry(SideKind.LANGUAGE, "", I18n.get("aeternum.config.page.language"),
				I18n.get(AeternumLanguage.choice().translationKey()), y, Theme.ROW_DENSE, false));
			y += Theme.ROW_DENSE;
		}
		List<SuiteLinks.Member> members = showsSuite() ? SuiteLinks.members() : List.of();
		if (!members.isEmpty()) {
			sideEntries.add(new SideEntry(SideKind.CAPTION, "", I18n.get("aeternum.config.mods"), null, y,
				(Theme.LINE + Theme.SPACE_3), false));
			y += (Theme.LINE + Theme.SPACE_3);
			for (SuiteLinks.Member member : members) {
				boolean current = member.id().equals(MOD) && !themePage();
				sideEntries.add(new SideEntry(SideKind.MOD, member.id(), member.name(), member.version(), y,
					Theme.ROW_DENSE, current));
				y += Theme.ROW_DENSE;
			}
		}
		sideHeight = y;
		if (revealCurrent) {
			revealCurrent = false;
			int view = sideListBottom() - sideListTop();
			for (SideEntry entry : sideEntries) {
				if (entry.kind() == SideKind.MOD && entry.key().equals(MOD)
					&& entry.virtualY() + entry.height() > sideScroll + view) {
					sideScroll = entry.virtualY() - view / 2.0;
				}
			}
		}
		sideScroll = Math.clamp(sideScroll, 0, maxSideScroll());
	}

	private String firstPageOf(String group) {
		for (Map.Entry<String, List<Row>> entry : sections.entrySet()) {
			if (!entry.getValue().isEmpty() && group.equals(sectionGroups.get(entry.getKey()))) {
				return entry.getKey();
			}
		}
		return null;
	}

	private int maxSideScroll() {
		return Math.max(0, sideHeight - (sideListBottom() - sideListTop()));
	}

	private boolean inSidebar(double mouseX, double mouseY) {
		return mouseX >= panelX && mouseX < sidebarRight() && mouseY >= sideListTop() && mouseY < sideListBottom();
	}

	private SideEntry sideEntryAt(double mouseX, double mouseY) {
		if (!inSidebar(mouseX, mouseY)) {
			return null;
		}
		for (SideEntry entry : sideEntries) {
			int top = sideListTop() + entry.virtualY() - (int) sideScroll;
			if (entry.kind() != SideKind.CAPTION && mouseY >= top && mouseY < top + entry.height()) {
				return entry;
			}
		}
		return null;
	}

	private boolean clickSidebar(double mouseX, double mouseY) {
		SideEntry entry = sideEntryAt(mouseX, mouseY);
		if (entry == null) {
			return false;
		}
		switch (entry.kind()) {
			case APPEARANCE -> selectPage(THEME_SECTION);
			case LANGUAGE -> {
				AeternumLanguage.cycle();
				refresh();
			}
			case MOD -> {
				if (!entry.key().equals(MOD) && minecraft != null) {
					save();
					minecraft.setScreenAndShow(SuiteLinks.open(entry.key(), parent));
				} else if (themePage()) {
					selectPage(firstPage());
				}
			}
			case CAPTION -> {
			}
		}
		return true;
	}

	private Tab tabAt(double mouseX, double mouseY) {
		for (Tab tab : tabs) {
			if (mouseX >= tab.x() && mouseX < tab.x() + tab.width() && mouseY >= tab.y()
				&& mouseY < tab.y() + Theme.ROW_DENSE) {
				return tab;
			}
		}
		return null;
	}

	private boolean clickTab(double mouseX, double mouseY) {
		Tab tab = tabAt(mouseX, mouseY);
		if (tab == null) {
			return false;
		}
		if (tab.group()) {
			String first = firstPageOf(tab.key());
			if (first != null && !tab.current()) {
				selectPage(first);
			}
		} else {
			selectPage(tab.key());
		}
		return true;
	}

	@Override
	public boolean mouseClicked(MouseButtonEvent click, boolean doubleClick) {
		if (dropdown.isOpen()) {
			return dropdown.mouseClicked(click.x(), click.y(), click.button());
		}
		if (picker.isOpen()) {
			return picker.mouseClicked(click.x(), click.y(), click.button());
		}
		if (click.button() == InputConstants.MOUSE_BUTTON_LEFT && overScrollbar(click.x(), click.y())) {
			draggingScrollbar = true;
			dragScrollbar(click.y());
			return true;
		}
		if (click.button() == InputConstants.MOUSE_BUTTON_LEFT
			&& (clickSidebar(click.x(), click.y()) || clickTab(click.x(), click.y()))) {
			return true;
		}
		return super.mouseClicked(click, doubleClick);
	}

	@Override
	public boolean mouseDragged(MouseButtonEvent click, double offsetX, double offsetY) {
		if (draggingScrollbar) {
			dragScrollbar(click.y());
			return true;
		}
		if (picker.mouseDragged(click.x(), click.y())) {
			return true;
		}
		return super.mouseDragged(click, offsetX, offsetY);
	}

	@Override
	public boolean mouseReleased(MouseButtonEvent click) {
		if (draggingScrollbar) {
			draggingScrollbar = false;
			return true;
		}
		if (picker.mouseReleased()) {
			return true;
		}
		return super.mouseReleased(click);
	}

	private int scrollbarX() {
		return centerLeft + centerWidth + 4;
	}

	private boolean overScrollbar(double mouseX, double mouseY) {
		int x = scrollbarX();
		return maxScroll() > 0 && inContentBand(mouseY)
			&& mouseX >= x - SCROLLBAR_HIT + Theme.SCROLLBAR_WIDTH && mouseX < x + Theme.SCROLLBAR_WIDTH + 2;
	}

	private void dragScrollbar(double mouseY) {
		int track = contentViewHeight();
		int thumb = Math.max(20, track * track / Math.max(1, contentHeight));
		double travel = Math.max(1, track - thumb);
		double ratio = (mouseY - contentTop() - thumb / 2.0) / travel;
		scroll = Math.clamp(ratio * maxScroll(), 0, maxScroll());
		position();
	}

	@Override
	public boolean keyPressed(KeyEvent input) {
		if (dropdown.keyPressed(input.key())) {
			return true;
		}
		if (picker.keyPressed(input.key())) {
			return true;
		}
		return super.keyPressed(input);
	}

	@Override
	public boolean charTyped(CharacterEvent input) {
		if (dropdown.isOpen()) {
			return true;
		}
		if (picker.charTyped((char) input.codepoint())) {
			return true;
		}
		return super.charTyped(input);
	}

	@Override
	public boolean mouseScrolled(double mouseX, double mouseY, double horizontal, double vertical) {
		if (dropdown.mouseScrolled(vertical)) {
			return true;
		}
		if (picker.isOpen()) {
			return true;
		}
		if (inSidebar(mouseX, mouseY) && maxSideScroll() > 0) {
			sideScroll = Math.clamp(sideScroll - vertical * Theme.ROW_DENSE, 0, maxSideScroll());
			return true;
		}
		if (inContentBand(mouseY) && maxScroll() > 0) {
			scroll = Math.clamp(scroll - vertical * Theme.SETTING_ROW_HEIGHT, 0, maxScroll());
			position();
			return true;
		}
		return super.mouseScrolled(mouseX, mouseY, horizontal, vertical);
	}

	@Override
	public void onClose() {
		save();
		if (minecraft != null) {
			minecraft.setScreenAndShow(parent);
		}
	}

	@Override
	public boolean isPauseScreen() {
		return false;
	}

	@Override
	public void extractRenderState(GuiGraphicsExtractor context, int mouseX, int mouseY, float delta) {
		Theme.sync();
		for (Row row : allRows) {
			row.widget.active = row.active();
		}
		boolean overlay = picker.isOpen() || dropdown.isOpen();
		int pointerX = overlay ? -1 : mouseX;
		int pointerY = overlay ? -1 : mouseY;

		Panel.backdrop(context, width, height);
		renderBehindPanel(context, pointerX, pointerY);
		Shape.window(context, panelX, panelY, panelX + panelWidth, panelY + panelHeight);
		context.fill(sidebarRight(), panelY + Theme.WINDOW_RADIUS, sidebarRight() + 1,
			panelY + panelHeight - Theme.WINDOW_RADIUS, Theme.HAIRLINE);

		drawSidebarHeader(context);
		drawSidebar(context, pointerX, pointerY);
		drawMainHeader(context, pointerX, pointerY);

		context.enableScissor(centerLeft - 8, contentTop(), centerRight() + 8, contentBottom());
		if (filtering()) {
			for (Section section : visibleSections) {
				int y = contentTop() + section.virtualY() - (int) scroll;
				drawHeading(context, Component.literal(pageLabel(section.key())), centerLeft, centerRight(), y);
			}
		}
		for (Row row : allRows) {
			if (row.shown && row.widget.visible) {
				row.widget.extractRenderState(context, pointerX, pointerY, delta);
				drawDescription(context, row);
			}
		}
		if (visibleSections.isEmpty()) {
			Component empty = Fonts.ui(Component.translatable("aeternum.config.no_match"));
			context.text(font, empty, centerLeft + (columnWidth - font.width(empty)) / 2,
				contentTop() + contentViewHeight() / 2 - 4, Theme.TEXT_SECONDARY, false);
		}
		context.disableScissor();

		if (asideShown) {
			drawAside(context, pointerX, pointerY);
		}
		super.extractRenderState(context, pointerX, pointerY, delta);

		drawFooterHint(context);
		Panel.scrollbar(context, scrollbarX(), contentTop(), contentViewHeight(), contentHeight, scroll);
		if (!overlay) {
			drawSettingTooltip(context, mouseX, mouseY);
		}
		picker.render(context, font, mouseX, mouseY);
		dropdown.render(context, font, mouseX, mouseY);
	}

	private void drawSidebarHeader(GuiGraphicsExtractor context) {
		int left = panelX + Theme.SPACE_4 + Theme.SPACE_3;
		int top = bodyTop();
		Shape.fill(context, left, top, left + LOGO, top + LOGO, Theme.TILE_RADIUS, Theme.ACCENT);
		Component logo = Fonts.strong("Æ");
		context.text(font, logo, left + (LOGO - font.width(logo)) / 2 + 1, top + (LOGO - 9) / 2 + 1, Theme.ON_ACCENT,
			false);
		int textX = left + LOGO + 7;
		int maxWidth = sidebarRight() - Theme.SPACE_4 - textX;
		context.text(font, Fit.line(font, Fonts.ui(Component.translatable("aeternum.config.suite")), maxWidth), textX, top + 1,
			Theme.TEXT_PRIMARY, false);
		Component count = Fonts.small(Component.translatable("aeternum.config.suite_count", suiteSize(),
			minecraftVersion()));
		context.text(font, Fit.line(font, count, maxWidth), textX, top + 13, Theme.TEXT_SECONDARY, false);
	}

	private static String minecraftVersion() {
		return FabricLoader.getInstance().getModContainer("minecraft")
			.map(mod -> mod.getMetadata().getVersion().getFriendlyString()).orElse("");
	}

	private void drawSidebar(GuiGraphicsExtractor context, int mouseX, int mouseY) {
		SideEntry hovered = sideEntryAt(mouseX, mouseY);
		int left = panelX + Theme.SPACE_4;
		int right = sidebarRight() - Theme.SPACE_4;
		context.enableScissor(panelX + 1, sideListTop(), sidebarRight(), sideListBottom());
		for (SideEntry entry : sideEntries) {
			int top = sideListTop() + entry.virtualY() - (int) sideScroll;
			if (top + entry.height() < sideListTop() || top > sideListBottom()) {
				continue;
			}
			if (entry.kind() == SideKind.CAPTION) {
				context.text(font, Fonts.small(entry.label()), left + Theme.SPACE_3, top + entry.height() - 10,
					Theme.TEXT_SECONDARY, false);
				continue;
			}
			boolean hot = entry == hovered && !entry.current();
			if (entry.current()) {
				Shape.fill(context, left, top, right, top + entry.height(), Theme.TILE_RADIUS, Theme.TILE);
			} else if (hot) {
				Shape.fill(context, left, top, right, top + entry.height(), Theme.TILE_RADIUS,
					Theme.alpha(Theme.TILE, 0xA0));
			}
			int textY = top + (entry.height() - 9) / 2 + 1;
			int valueWidth = 0;
			if (entry.value() != null && !entry.value().isEmpty()) {
				Component value = Fonts.small(entry.value());
				valueWidth = font.width(value) + 6;
				context.text(font, value, right - Theme.SPACE_3 - font.width(value), textY + 1, Theme.TEXT_SECONDARY,
					false);
			}
			int color = entry.current() ? Theme.ACCENT : hot ? Theme.TEXT_PRIMARY
				: Theme.mix(Theme.TEXT_PRIMARY, Theme.TEXT_SECONDARY, 0.35);
			int maxWidth = right - left - Theme.SPACE_3 * 2 - valueWidth;
			context.text(font, Fit.line(font, Fonts.ui(entry.label()), maxWidth), left + Theme.SPACE_3, textY, color, false);
		}
		context.disableScissor();
		if (maxSideScroll() > 0) {
			Panel.scrollbar(context, sidebarRight() - Theme.SCROLLBAR_WIDTH - 2, sideListTop(),
				sideListBottom() - sideListTop(), sideHeight, sideScroll);
		}
	}

	private void drawMainHeader(GuiGraphicsExtractor context, int mouseX, int mouseY) {
		int top = panelY + Theme.SPACE_5;
		Component heading = themePage() ? Component.translatable("aeternum.config.page.appearance")
			: filtering() ? Component.translatable("aeternum.config.results",
				allRows.stream().filter(row -> row.shown && !row.heading).count())
			: title;
		Type.X2.draw(context, font, Fit.line(font, heading, (mainRight - centerLeft) / 2), centerLeft, top, Theme.TEXT_PRIMARY);
		Component subtitle = subtitle();
		if (subtitle != null) {
			context.text(font, Fit.line(font, Fonts.ui(subtitle), mainRight - centerLeft), centerLeft, top + (Theme.LINE_2 + Theme.SPACE_2),
				Theme.TEXT_SECONDARY, false);
		}
		Tab hovered = tabAt(mouseX, mouseY);
		int rowY = Integer.MIN_VALUE;
		int rowStart = 0;
		int rowEnd = 0;
		List<int[]> wells = new ArrayList<>();
		for (Tab tab : tabs) {
			if (tab.y() != rowY) {
				if (rowY != Integer.MIN_VALUE) {
					wells.add(new int[] {rowStart, rowY, rowEnd});
				}
				rowY = tab.y();
				rowStart = tab.x() - Shape.SEGMENT_PAD;
			}
			rowEnd = tab.x() + tab.width() + Shape.SEGMENT_PAD;
		}
		if (rowY != Integer.MIN_VALUE) {
			wells.add(new int[] {rowStart, rowY, rowEnd});
		}
		for (int[] well : wells) {
			Shape.well(context, well[0], well[1], well[2], well[1] + Theme.ROW_DENSE);
		}
		for (Tab tab : tabs) {
			boolean hot = tab == hovered && !tab.current();
			Shape.chip(context, tab.x(), tab.y() + Shape.SEGMENT_PAD, tab.x() + tab.width(),
				tab.y() + Theme.ROW_DENSE - Shape.SEGMENT_PAD, tab.current(), hot);
			int color = tab.current() ? Theme.ON_ACCENT : hot ? Theme.TEXT_PRIMARY
				: Theme.mix(Theme.TEXT_PRIMARY, Theme.TEXT_SECONDARY, 0.35);
			context.text(font, tab.label(), tab.x() + Theme.SPACE_4, tab.y() + (Theme.ROW_DENSE - 9) / 2 + 1, color, false);
		}
	}

	private void drawHeading(GuiGraphicsExtractor context, Component label, int left, int right, int y) {
		Component shown = Fonts.ui(label);
		int textY = y + (Theme.LINE + Theme.SPACE_5) - 13;
		context.text(font, shown, left, textY, Theme.TEXT_SECONDARY, false);
		int ruleX = left + font.width(shown) + 7;
		if (ruleX < right) {
			context.fill(ruleX, textY + 4, right, textY + 5, Theme.HAIRLINE);
		}
	}

	private int previewTop() {
		return panelY + Theme.SPACE_5 + 4;
	}

	private int lookPreviewHeight() {
		return 150;
	}

	private void drawAside(GuiGraphicsExtractor context, int mouseX, int mouseY) {
		int left = asideLeft();
		int top = previewTop();
		if (themePage()) {
			context.text(font, Fonts.ui(Component.translatable("aeternum.config.preview_live")), left, top,
				Theme.TEXT_SECONDARY, false);
			drawLookPreview(context, left, top + 16, Theme.ASIDE);
			return;
		}
		int bottom = footerSeparatorY() - Theme.PADDING;
		renderPreview(context, left, top, Theme.ASIDE, previewHeight(bottom - top), mouseX, mouseY);
	}

	private void drawLookPreview(GuiGraphicsExtractor context, int x, int y, int width) {
		int pad = switch (Theme.DENSITY) {
			case COMPACT -> 6;
			case AIRY -> 13;
			case NORMAL -> 9;
		};
		int gap = Math.max(4, pad - 2);
		int inner = width - pad * 2;
		int avatar = 20;
		int barY = y + pad + avatar + gap + 32 + gap;
		int chatY = barY + 18 + gap;
		int bottom = chatY + 14 + pad;
		Shape.card(context, x, y, x + width, bottom);
		int left = x + pad;
		int top = y + pad;
		Shape.fill(context, left, top, left + avatar, top + avatar, Theme.TILE_RADIUS, Theme.ACCENT);
		String name = minecraft != null ? minecraft.getUser().getName() : "Joueur";
		Component initial = Fonts.strong(name.isEmpty() ? "?" : name.substring(0, 1).toUpperCase(Locale.ROOT));
		context.text(font, initial, left + (avatar - font.width(initial)) / 2 + 1, top + 6, Theme.ON_ACCENT, false);
		context.text(font, name, left + avatar + 6, top + 1, Theme.TEXT_PRIMARY, false);
		context.text(font, Fonts.small(Component.translatable("aeternum.config.preview_role")), left + avatar + 6,
			top + 12, Theme.TEXT_SECONDARY, false);
		Component pill = Fonts.small("6 / 12");
		int pillW = font.width(pill) + 10;
		int pillX = x + width - pad - pillW;
		Shape.pill(context, pillX, top + 5, pillX + pillW, top + 15, Theme.TILE);
		context.text(font, pill, pillX + 5, top + 7, Theme.ACCENT, false);

		int tileTop = top + avatar + gap;
		int tileW = (inner - 4) / 2;
		drawPreviewTile(context, left, tileTop, tileW, "aeternum.config.preview_waypoints", "24", Theme.TEXT_PRIMARY);
		drawPreviewTile(context, left + tileW + 4, tileTop, tileW, "aeternum.config.preview_chests", "186",
			Theme.ACCENT);

		context.text(font, Fonts.small(Component.translatable("aeternum.config.preview_bar")), left, barY,
			Theme.TEXT_SECONDARY, false);
		Component percent = Fonts.small("97 %");
		context.text(font, percent, left + inner - font.width(percent), barY, Theme.TEXT_SECONDARY, false);
		Shape.pill(context, left, barY + 11, left + inner, barY + 15, Theme.opaque(Theme.WINDOW));
		Shape.pill(context, left, barY + 11, left + (int) (inner * 0.975), barY + 15, Theme.ACCENT);

		Shape.fill(context, left, chatY, left + inner, chatY + 14, Theme.TILE_RADIUS, Theme.alpha(Theme.WINDOW, 0x99));
		int cx = left + 4;
		context.text(font, "21:40", cx, chatY + 3, 0xFFE9BD63, false);
		cx += font.width("21:40 ");
		context.text(font, "Brumir", cx, chatY + 3, 0xFF5FD4E8, false);
		cx += font.width("Brumir ");
		context.text(font, "> j'arrive", cx, chatY + 3, Theme.TEXT_PRIMARY, false);
	}

	private void drawPreviewTile(GuiGraphicsExtractor context, int x, int y, int w, String labelKey, String value,
			int valueColor) {
		Shape.tile(context, x, y, x + w, y + 32);
		context.text(font, Fit.line(font, Component.translatable(labelKey), w - 12), x + 6, y + 5, Theme.TEXT_SECONDARY, false);
		context.text(font, Fit.line(font, Component.literal(value), w - 12), x + 6, y + 18, valueColor, false);
	}

	private Row hoveredRow(int mouseX, int mouseY) {
		if (!inContentBand(mouseY)) {
			return null;
		}
		for (Row row : allRows) {
			if (row.shown && row.widget.visible && row.widget.isMouseOver(mouseX, mouseY)) {
				return row;
			}
		}
		return null;
	}

	protected final void status(String message) {
		status = message == null ? "" : message;
	}

	private void drawFooterHint(GuiGraphicsExtractor context) {
		int available = mainRight - mainLeft - Theme.FOOTER_BUTTON_WIDTH - Theme.GUTTER - footerReserve();
		int y = footerTop() + (Theme.FOOTER_HEIGHT - 9) / 2 + 1;
		if (!status.isEmpty()) {
			context.text(font, Fit.line(font, Fonts.ui(status), Math.max(0, available)), mainLeft, y, Theme.ACCENT, false);
		}
	}

	protected int footerReserve() {
		return 0;
	}

	private void drawSettingTooltip(GuiGraphicsExtractor context, int mouseX, int mouseY) {
		Row row = hoveredRow(mouseX, mouseY);
		if (row == null) {
			return;
		}
		if (row.widget instanceof TooltipSource source) {
			List<FormattedCharSequence> custom = source.tooltip(font);
			if (!custom.isEmpty()) {
				context.setTooltipForNextFrame(font, custom, mouseX, mouseY);
			}
		}
	}

	protected static void drawRowLabel(GuiGraphicsExtractor context, Font font, Component label,
			int x, int y, int maxWidth, int color) {
		context.text(font, Fit.line(font, Fonts.ui(label), Math.max(0, maxWidth)), x, y, color, false);
	}

	protected static void drawRowBackground(GuiGraphicsExtractor context, AbstractWidget widget, boolean hot) {
		if (hot) {
			Shape.fill(context, widget.getX() - 6, widget.getY(), widget.getRight() + 6,
				widget.getBottom(), Theme.TILE_RADIUS, Theme.alpha(Theme.TEXT_PRIMARY, 0x08));
		}
	}

	protected static void drawSwatch(GuiGraphicsExtractor context, int right, int y, int height,
			int rgb, boolean hot, boolean active) {
		int swatchX = right - Theme.SWATCH_WIDTH;
		int swatchY = y + (height - Theme.SWATCH_HEIGHT - 2) / 2;
		Shape.fill(context, swatchX, swatchY, right, swatchY + Theme.SWATCH_HEIGHT + 2, Theme.TILE_RADIUS,
			active ? Theme.opaque(rgb) : Theme.TILE);
		if (hot) {
			Shape.stroke(context, swatchX - 2, swatchY - 2, right + 2, swatchY + Theme.SWATCH_HEIGHT + 4,
				Theme.TILE_RADIUS + 2, 1, Theme.TEXT_PRIMARY);
		}
	}

	private static void drawValueButton(GuiGraphicsExtractor context, Font font, int right, int centerY,
			Component value, boolean chevron, boolean hot, boolean active) {
		int textWidth = font.width(value);
		int w = textWidth + 16 + (chevron ? CHEVRON + 5 : 0);
		int h = 18;
		int x = right - w;
		int y = centerY - h / 2;
		Shape.fill(context, x, y, right, y + h, Theme.TILE_RADIUS,
			hot ? Theme.mix(Theme.TILE, Theme.TEXT_PRIMARY, 0.08) : Theme.TILE);
		int color = active ? Theme.TEXT_PRIMARY : Theme.TEXT_DISABLED;
		context.text(font, value, x + 8, y + (h - 9) / 2 + 1, color, false);
		if (chevron) {
			chevron(context, right - 8 - CHEVRON, y + (h - CHEVRON) / 2, true, active ? Theme.TEXT_SECONDARY
				: Theme.TEXT_DISABLED);
		}
	}

	private static int valueButtonWidth(Font font, Component value, boolean chevron) {
		return font.width(value) + 16 + (chevron ? CHEVRON + 5 : 0);
	}

	private static void chevron(GuiGraphicsExtractor context, int x, int y, boolean open, int color) {
		context.blit(RenderPipelines.GUI_TEXTURED, open ? CHEVRON_DOWN : CHEVRON_RIGHT, x, y, 0, 0, CHEVRON, CHEVRON,
			CHEVRON, CHEVRON, color);
	}

	protected abstract class SettingButton extends AbstractButton {
		final boolean stackable;
		int labelTop = -1;

		protected SettingButton(int x, int width, Component label) {
			super(x, 0, width, Theme.SETTING_ROW_HEIGHT, label);
			this.stackable = true;
		}

		protected SettingButton(int x, int width, int height, Component label) {
			super(x, 0, width, height, label);
			this.stackable = false;
		}

		@Override
		public boolean isMouseOver(double mouseX, double mouseY) {
			return super.isMouseOver(mouseX, mouseY) && inContentBand(mouseY);
		}

		protected boolean hot(int mouseX, int mouseY) {
			return active && (isMouseOver(mouseX, mouseY) || isFocused());
		}

		protected int labelColor() {
			return active ? Theme.TEXT_PRIMARY : Theme.TEXT_DISABLED;
		}

		protected int textY() {
			return labelTop >= 0 ? getY() + labelTop + 1 : getY() + (getHeight() - 9) / 2 + 1;
		}

		protected int controlY() {
			return getY() + getHeight() / 2;
		}

		protected int controlWidth() {
			return CONTROL_WIDTH;
		}

		protected Font font() {
			return Minecraft.getInstance().font;
		}

		@Override
		protected void updateWidgetNarration(NarrationElementOutput builder) {
			defaultButtonNarrationText(builder);
		}
	}

	protected class ToggleRow extends SettingButton {
		private final Consumer<Boolean> setter;
		private boolean value;

		public ToggleRow(int x, int width, Component label, boolean initial, Consumer<Boolean> setter) {
			super(x, width, label);
			this.value = initial;
			this.setter = setter;
		}

		@Override
		public void onPress(InputWithModifiers input) {
			value = !value;
			setter.accept(value);
		}

		@Override
		protected int controlWidth() {
			return Shape.SWITCH_WIDTH;
		}

		@Override
		protected void extractContents(GuiGraphicsExtractor context, int mouseX, int mouseY, float delta) {
			boolean hot = hot(mouseX, mouseY);
			drawRowBackground(context, this, hot);
			int trackX = getRight() - Shape.SWITCH_WIDTH;
			drawRowLabel(context, font(), getMessage(), getX(), textY(), trackX - getX() - Theme.GUTTER, labelColor());
			Shape.toggle(context, trackX, controlY() - Shape.SWITCH_HEIGHT / 2, value, active, hot);
		}
	}

	protected class ChoiceRow extends SettingButton {
		private final Supplier<String> valueKey;
		private final Runnable cycle;
		private final boolean translate;

		public ChoiceRow(int x, int width, Component label, Supplier<String> valueKey, Runnable cycle) {
			this(x, width, label, valueKey, cycle, true);
		}

		public ChoiceRow(int x, int width, Component label, Supplier<String> valueKey, Runnable cycle,
				boolean translate) {
			super(x, width, label);
			this.valueKey = valueKey;
			this.cycle = cycle;
			this.translate = translate;
		}

		private Component value() {
			return Fonts.ui(translate ? I18n.get(valueKey.get()) : valueKey.get());
		}

		@Override
		public void onPress(InputWithModifiers input) {
			cycle.run();
		}

		@Override
		protected int controlWidth() {
			return Math.min(getWidth() / 2, valueButtonWidth(font(), value(), false));
		}

		@Override
		protected void extractContents(GuiGraphicsExtractor context, int mouseX, int mouseY, float delta) {
			boolean hot = hot(mouseX, mouseY);
			drawRowBackground(context, this, hot);
			Font font = font();
			Component value = value();
			int buttonWidth = valueButtonWidth(font, value, false);
			drawRowLabel(context, font, getMessage(), getX(), textY(), getWidth() - buttonWidth - Theme.GUTTER,
				labelColor());
			drawValueButton(context, font, getRight(), controlY(), value, false, hot, active);
		}
	}

	protected class DropdownRow extends SettingButton {
		private final Supplier<List<String>> labels;
		private final IntSupplier selected;
		private final IntConsumer select;

		public DropdownRow(int x, int width, Component label, Supplier<List<String>> labels, IntSupplier selected,
				IntConsumer select) {
			super(x, width, label);
			this.labels = labels;
			this.selected = selected;
			this.select = select;
		}

		private Component value() {
			List<String> options = labels.get();
			int index = selected.getAsInt();
			String value = index >= 0 && index < options.size() ? options.get(index) : "";
			return Fonts.ui(Fit.text(font, value, Math.max(0, getWidth() / 2 - 30)));
		}

		@Override
		public void onPress(InputWithModifiers input) {
			openDropdown(this, labels.get(), selected.getAsInt(), select);
		}

		@Override
		protected int controlWidth() {
			return valueButtonWidth(font(), value(), true);
		}

		@Override
		protected void extractContents(GuiGraphicsExtractor context, int mouseX, int mouseY, float delta) {
			boolean hot = hot(mouseX, mouseY);
			drawRowBackground(context, this, hot);
			Font font = font();
			Component value = value();
			int buttonWidth = valueButtonWidth(font, value, true);
			drawRowLabel(context, font, getMessage(), getX(), textY(), getWidth() - buttonWidth - Theme.GUTTER,
				labelColor());
			drawValueButton(context, font, getRight(), controlY(), value, true, hot, active);
		}
	}

	protected class SegmentRow extends SettingButton {
		private static final int TRACK_WIDTH = 200;
		private static final int TRACK_HEIGHT = 19;

		private final List<String> labels;
		private final IntSupplier selected;
		private final IntConsumer select;
		private int pressedAt = -1;

		public SegmentRow(int x, int width, Component label, List<String> labels, IntSupplier selected,
				IntConsumer select) {
			super(x, width, label);
			this.labels = labels;
			this.selected = selected;
			this.select = select;
		}

		private int trackLeft() {
			return getRight() - Math.min(TRACK_WIDTH, getWidth() / 2);
		}

		@Override
		protected int controlWidth() {
			return Math.min(TRACK_WIDTH, getWidth() / 2);
		}

		@Override
		public void onClick(MouseButtonEvent click, boolean doubleClick) {
			pressedAt = Shape.segmentAt(trackLeft(), getRight(), labels.size(), click.x());
			super.onClick(click, doubleClick);
		}

		@Override
		public void onPress(InputWithModifiers input) {
			int index = pressedAt >= 0 ? pressedAt : (selected.getAsInt() + 1) % labels.size();
			pressedAt = -1;
			if (index != selected.getAsInt()) {
				select.accept(index);
			}
		}

		@Override
		protected void extractContents(GuiGraphicsExtractor context, int mouseX, int mouseY, float delta) {
			Font font = font();
			int left = trackLeft();
			drawRowLabel(context, font, getMessage(), getX(), textY(), left - getX() - Theme.GUTTER, labelColor());
			int top = controlY() - TRACK_HEIGHT / 2;
			int current = selected.getAsInt();
			int hovered = isMouseOver(mouseX, mouseY) && active ? Shape.segmentAt(left, getRight(), labels.size(), mouseX)
				: -1;
			Shape.segments(context, left, top, getRight(), top + TRACK_HEIGHT, labels.size(), current, hovered);
			for (int i = 0; i < labels.size(); i++) {
				int x0 = Shape.segmentLeft(left, getRight(), labels.size(), i);
				int x1 = Shape.segmentLeft(left, getRight(), labels.size(), i + 1) - Shape.SEGMENT_GAP;
				Component text = Fonts.ui(labels.get(i));
				FormattedCharSequence shown = Fit.line(font, text, x1 - x0 - 4);
				int textWidth = font.width(shown);
				int color = !active ? Theme.TEXT_DISABLED : i == current ? Theme.ON_ACCENT
					: i == hovered ? Theme.TEXT_PRIMARY : Theme.mix(Theme.TEXT_PRIMARY, Theme.TEXT_SECONDARY, 0.35);
				context.text(font, shown, x0 + (x1 - x0 - textWidth) / 2, top + (TRACK_HEIGHT - 9) / 2 + 1, color, false);
			}
		}
	}

	protected class ThemeCards extends SettingButton {
		private static final int CARD_HEIGHT = 48;
		private static final AeternumTheme.Preset[] PRESETS = {AeternumTheme.Preset.LICHEN,
			AeternumTheme.Preset.AMBRE, AeternumTheme.Preset.FJORD, AeternumTheme.Preset.AMETHYSTE};
		private int pressedAt = -1;

		public ThemeCards(int x, int width) {
			super(x, width, CARD_HEIGHT, Component.translatable("aeternum.config.themes"));
		}

		private int cardLeft(int index) {
			return getX() + (getWidth() + 6) * index / PRESETS.length;
		}

		private int cardAt(double mouseX) {
			for (int i = 0; i < PRESETS.length; i++) {
				if (mouseX >= cardLeft(i) && mouseX < cardLeft(i + 1) - 6) {
					return i;
				}
			}
			return -1;
		}

		@Override
		public void onClick(MouseButtonEvent click, boolean doubleClick) {
			pressedAt = cardAt(click.x());
			super.onClick(click, doubleClick);
		}

		@Override
		public void onPress(InputWithModifiers input) {
			int index = pressedAt;
			pressedAt = -1;
			if (index < 0) {
				return;
			}
			AeternumTheme.select(PRESETS[index]);
			restyle(s -> s.withAccent(AeternumTheme.Style.THEME_ACCENT));
			onThemeChanged();
		}

		@Override
		protected void extractContents(GuiGraphicsExtractor context, int mouseX, int mouseY, float delta) {
			Font font = font();
			int hovered = isMouseOver(mouseX, mouseY) ? cardAt(mouseX) : -1;
			for (int i = 0; i < PRESETS.length; i++) {
				AeternumTheme.Preset preset = PRESETS[i];
				AeternumTheme.Palette palette = preset.palette();
				boolean on = AeternumTheme.preset() == preset;
				int x0 = cardLeft(i);
				int x1 = cardLeft(i + 1) - 6;
				int y0 = getY();
				int y1 = getY() + CARD_HEIGHT;
				Shape.fill(context, x0, y0, x1, y1, Theme.RADIUS, Theme.CARD);
				Shape.stroke(context, x0, y0, x1, y1, Theme.RADIUS, 1,
					on ? Theme.ACCENT : i == hovered ? Theme.alpha(Theme.TEXT_PRIMARY, 0x30)
						: Theme.alpha(Theme.TEXT_PRIMARY, 0x10));
				int mx0 = x0 + 6;
				int my0 = y0 + 6;
				int mx1 = x1 - 6;
				int my1 = my0 + 22;
				Shape.fill(context, mx0, my0, mx1, my1, Theme.TILE_RADIUS, Theme.opaque(palette.background()));
				Shape.fill(context, mx0 + 4, my0 + 4, mx0 + 18, my1 - 4, Math.max(0, Theme.TILE_RADIUS - 2),
					Theme.opaque(palette.accent()));
				Shape.pill(context, mx0 + 22, my0 + 7, mx0 + 22 + (mx1 - mx0 - 26) * 4 / 5, my0 + 9,
					Theme.alpha(0xFFFFFFFF, 0x5A));
				Shape.pill(context, mx0 + 22, my0 + 12, mx0 + 22 + (mx1 - mx0 - 26) / 2, my0 + 14,
					Theme.alpha(0xFFFFFFFF, 0x2E));
				Component name = Fonts.ui(Component.translatable(preset.translationKey()));
				context.text(font, Fit.line(font, name, x1 - x0 - 12), x0 + 6, my1 + 6, Theme.TEXT_PRIMARY, false);
			}
		}
	}

	protected class AccentRow extends SettingButton {
		private static final int SWATCH = 18;
		private static final int GAP = 4;
		private int pressedAt = -1;

		public AccentRow(int x, int width) {
			super(x, width, Component.translatable("aeternum.config.accent"));
		}

		private int count() {
			return ACCENTS.length + 1;
		}

		private int swatchLeft(int index) {
			return getRight() - (count() - index) * (SWATCH + GAP) + GAP;
		}

		private int swatchAt(double mouseX) {
			for (int i = 0; i < count(); i++) {
				if (mouseX >= swatchLeft(i) && mouseX < swatchLeft(i) + SWATCH) {
					return i;
				}
			}
			return -1;
		}

		@Override
		protected int controlWidth() {
			return count() * (SWATCH + GAP);
		}

		@Override
		public void onClick(MouseButtonEvent click, boolean doubleClick) {
			pressedAt = swatchAt(click.x());
			super.onClick(click, doubleClick);
		}

		@Override
		public void onPress(InputWithModifiers input) {
			int index = pressedAt;
			pressedAt = -1;
			if (index < 0) {
				return;
			}
			if (index < ACCENTS.length) {
				pick(ACCENTS[index]);
				return;
			}
			openPicker(getMessage(), Theme.rgb(Theme.ACCENT), this, this::pick);
		}

		private void pick(int rgb) {
			int themeAccent = AeternumTheme.palette().accent();
			restyle(s -> s.withAccent((rgb & 0xFFFFFF) == themeAccent ? AeternumTheme.Style.THEME_ACCENT : rgb));
			onThemeChanged();
		}

		@Override
		protected void extractContents(GuiGraphicsExtractor context, int mouseX, int mouseY, float delta) {
			Font font = font();
			drawRowLabel(context, font, getMessage(), getX(), textY(), swatchLeft(0) - getX() - Theme.GUTTER,
				labelColor());
			int top = controlY() - SWATCH / 2;
			int current = Theme.rgb(Theme.ACCENT);
			int hovered = isMouseOver(mouseX, mouseY) ? swatchAt(mouseX) : -1;
			boolean custom = true;
			for (int i = 0; i < ACCENTS.length; i++) {
				int x0 = swatchLeft(i);
				boolean on = ACCENTS[i] == current;
				custom &= !on;
				Shape.fill(context, x0, top, x0 + SWATCH, top + SWATCH, Theme.TILE_RADIUS, Theme.opaque(ACCENTS[i]));
				if (on || i == hovered) {
					Shape.stroke(context, x0 - 2, top - 2, x0 + SWATCH + 2, top + SWATCH + 2, Theme.TILE_RADIUS + 2, 1,
						on ? Theme.TEXT_PRIMARY : Theme.alpha(Theme.TEXT_PRIMARY, 0x60));
				}
			}
			int x0 = swatchLeft(ACCENTS.length);
			if (custom) {
				Shape.fill(context, x0, top, x0 + SWATCH, top + SWATCH, Theme.TILE_RADIUS, Theme.ACCENT);
				Shape.stroke(context, x0 - 2, top - 2, x0 + SWATCH + 2, top + SWATCH + 2, Theme.TILE_RADIUS + 2, 1,
					Theme.TEXT_PRIMARY);
			} else {
				Shape.fill(context, x0, top, x0 + SWATCH, top + SWATCH, Theme.TILE_RADIUS,
					hovered == ACCENTS.length ? Theme.mix(Theme.TILE, Theme.TEXT_PRIMARY, 0.08) : Theme.TILE);
				Component plus = Fonts.strong("+");
				context.text(font, plus, x0 + (SWATCH - font.width(plus)) / 2 + 1, top + 5, Theme.TEXT_PRIMARY, false);
			}
		}
	}

	protected class ColorRow extends SettingButton {
		private final IntSupplier getter;
		private final IntConsumer setter;

		public ColorRow(int x, int width, Component label, IntSupplier getter, IntConsumer setter) {
			super(x, width, label);
			this.getter = getter;
			this.setter = setter;
		}

		@Override
		public void onPress(InputWithModifiers input) {
			openPicker(getMessage(), getter.getAsInt(), this, setter);
		}

		protected void drawSample(GuiGraphicsExtractor context, int x, int rgb) {
			int barY = controlY() - SAMPLE_BAR_HEIGHT / 2;
			Shape.pill(context, x, barY, x + SAMPLE_BAR_WIDTH, barY + SAMPLE_BAR_HEIGHT, Theme.opaque(rgb));
		}

		protected int sampleWidth() {
			return 0;
		}

		@Override
		protected int controlWidth() {
			return Theme.SWATCH_WIDTH + 50;
		}

		@Override
		protected void extractContents(GuiGraphicsExtractor context, int mouseX, int mouseY, float delta) {
			boolean hot = hot(mouseX, mouseY);
			drawRowBackground(context, this, hot);
			Font font = font();
			int rgb = getter.getAsInt() & 0xFFFFFF;
			int centerY = controlY();
			drawSwatch(context, getRight(), centerY - Theme.SWATCH_HEIGHT / 2 - 1, Theme.SWATCH_HEIGHT + 2, rgb, hot,
				active);
			Component hex = Fonts.ui("#" + AeternumTheme.hex(rgb));
			int hexWidth = font.width(hex);
			int hexX = getRight() - Theme.SWATCH_WIDTH - Theme.GUTTER - hexWidth;
			context.text(font, hex, hexX, centerY - 4, active ? Theme.TEXT_SECONDARY : Theme.TEXT_DISABLED, false);
			int labelRight = hexX - Theme.GUTTER;
			if (sampleWidth() > 0) {
				labelRight -= sampleWidth() + Theme.GUTTER;
				if (active) {
					drawSample(context, labelRight + Theme.GUTTER, rgb);
				}
			}
			drawRowLabel(context, font, getMessage(), getX(), textY(), labelRight - getX(), labelColor());
		}
	}

	protected class SliderRow extends AbstractSliderButton {
		private final String key;
		private final int min;
		private final int max;
		private final DoubleConsumer setter;
		private final IntFunction<String> format;
		private final int valueWidth;
		int labelTop = -1;

		public SliderRow(int x, int width, String key, int min, int max,
				DoubleSupplier getter, DoubleConsumer setter, IntFunction<String> format) {
			super(x, 0, width, Theme.SETTING_ROW_HEIGHT, Component.empty(),
				Math.clamp((getter.getAsDouble() - min) / (double) (max - min), 0.0, 1.0));
			this.key = key;
			this.min = min;
			this.max = max;
			this.setter = setter;
			this.format = format;
			Font font = Minecraft.getInstance().font;
			this.valueWidth = Math.max(SLIDER_VALUE, Math.max(font.width(Fonts.ui(format.apply(min))),
				font.width(Fonts.ui(format.apply(max)))));
			updateMessage();
		}

		private int current() {
			return (int) Math.round(min + value * (max - min));
		}

		private int trackRight() {
			return getRight() - valueWidth - 8;
		}

		private int trackLeft() {
			return trackRight() - Math.min(SLIDER_TRACK, getWidth() / 3);
		}

		int controlWidth() {
			return Math.min(SLIDER_TRACK, getWidth() / 3) + valueWidth + 8;
		}

		@Override
		protected void updateMessage() {
			setMessage(Component.translatable(key));
		}

		@Override
		protected void applyValue() {
			setter.accept(current());
		}

		@Override
		public boolean isMouseOver(double mouseX, double mouseY) {
			return super.isMouseOver(mouseX, mouseY) && inContentBand(mouseY);
		}

		private void follow(double mouseX) {
			setValue((mouseX - trackLeft()) / Math.max(1.0, trackRight() - trackLeft()));
		}

		@Override
		public void onClick(MouseButtonEvent click, boolean doubleClick) {
			follow(click.x());
		}

		@Override
		protected void onDrag(MouseButtonEvent click, double offsetX, double offsetY) {
			follow(click.x());
		}

		@Override
		public void extractWidgetRenderState(GuiGraphicsExtractor context, int mouseX, int mouseY, float delta) {
			boolean hot = active && (isMouseOver(mouseX, mouseY) || isFocused());
			drawRowBackground(context, this, hot);
			Font font = Minecraft.getInstance().font;
			Component shown = Fonts.ui(format.apply(current()));
			int textY = labelTop >= 0 ? getY() + labelTop + 1 : getY() + (getHeight() - 9) / 2 + 1;
			drawRowLabel(context, font, getMessage(), getX(), textY, trackLeft() - getX() - Theme.GUTTER,
				active ? Theme.TEXT_PRIMARY : Theme.TEXT_DISABLED);
			int centerY = getY() + getHeight() / 2;
			context.text(font, shown, getRight() - font.width(shown), centerY - 4,
				active ? Theme.TEXT_PRIMARY : Theme.TEXT_DISABLED, false);
			Shape.slider(context, trackLeft(), trackRight(), centerY, value, active);
		}
	}

	protected class TextRow extends FlatField implements Placeable {
		private static final double FIELD_FRACTION = 0.55;

		private final Component label;
		private int labelX;
		private int labelWidth;
		private final Function<String, String> validator;

		public TextRow(int x, int width, Component label, String value, Consumer<String> setter,
				Function<String, String> validator) {
			super(Minecraft.getInstance().font, x + (int) (width * (1 - FIELD_FRACTION)), 0,
				(int) (width * FIELD_FRACTION), Theme.FIELD_HEIGHT, label);
			this.label = label;
			this.labelX = x;
			this.labelWidth = (int) (width * (1 - FIELD_FRACTION)) - Theme.GUTTER;
			this.validator = validator;
			setMaxLength(512);
			setValue(value == null ? "" : value);
			moveCursorToStart(false);
			setResponder(text -> {
				if (error(text) == null) {
					setter.accept(text);
				}
			});
		}

		private String error(String text) {
			return validator == null ? null : validator.apply(text);
		}

		@Override
		public void setY(int y) {
			super.setY(y + (Theme.SETTING_ROW_HEIGHT - boxHeight()) / 2 + textOffset());
		}

		@Override
		public void place(int x, int width) {
			int labelArea = (int) (width * (1 - FIELD_FRACTION));
			labelX = x;
			labelWidth = labelArea - Theme.GUTTER;
			super.setX(x + labelArea + FlatField.PADDING);
			super.setWidth(Math.max(0, width - labelArea - FlatField.PADDING * 2));
		}

		@Override
		public boolean isMouseOver(double mouseX, double mouseY) {
			return super.isMouseOver(mouseX, mouseY) && inContentBand(mouseY);
		}

		@Override
		public void extractWidgetRenderState(GuiGraphicsExtractor context, int mouseX, int mouseY, float delta) {
			Font font = Minecraft.getInstance().font;
			drawRowLabel(context, font, label, labelX, boxY() + (boxHeight() - 9) / 2 + 1, labelWidth,
				active ? Theme.TEXT_PRIMARY : Theme.TEXT_DISABLED);
			invalid(error(getValue()) != null);
			super.extractWidgetRenderState(context, mouseX, mouseY, delta);
		}
	}

	protected class HeadingRow extends SettingButton {
		public HeadingRow(Component label) {
			super(0, 0, (Theme.LINE + Theme.SPACE_5), label);
		}

		@Override
		public void onPress(InputWithModifiers input) {
		}

		@Override
		public boolean isMouseOver(double mouseX, double mouseY) {
			return false;
		}

		@Override
		protected void extractContents(GuiGraphicsExtractor context, int mouseX, int mouseY, float delta) {
			drawHeading(context, getMessage(), getX(), getRight(), getY());
		}
	}

	protected class NoticeRow extends SettingButton {
		public NoticeRow(int x, int width, Component label) {
			super(x, width, Theme.SETTING_ROW_HEIGHT, label);
		}

		@Override
		public void onPress(InputWithModifiers input) {
		}

		@Override
		public boolean isMouseOver(double mouseX, double mouseY) {
			return false;
		}

		@Override
		protected void extractContents(GuiGraphicsExtractor context, int mouseX, int mouseY, float delta) {
			drawRowLabel(context, font(), getMessage(), getX(), textY(), getWidth(), Theme.TEXT_STALE);
		}
	}

	protected class ActionRow extends FlatButton implements Placeable {
		public ActionRow(int x, int width, Component label, Consumer<FlatButton> onPress) {
			super(x, 0, width, Theme.SETTING_ROW_HEIGHT - 4, label, onPress);
		}

		@Override
		public void place(int x, int width) {
			setX(x);
			setWidth(Math.min(width, Minecraft.getInstance().font.width(Fonts.ui(getMessage())) + 28));
		}

		@Override
		public boolean isMouseOver(double mouseX, double mouseY) {
			return super.isMouseOver(mouseX, mouseY) && inContentBand(mouseY);
		}
	}
}
