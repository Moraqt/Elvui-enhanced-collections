NineSliceLayouts = {
	

	Dialog                                   = {
		TopLeftCorner     = { atlas = "MetalFrame-CornerTopLeft" },
		TopRightCorner    = { atlas = "MetalFrame-CornerTopRight" },
		BottomLeftCorner  = { atlas = "MetalFrame-CornerBottomLeft" },
		BottomRightCorner = { atlas = "MetalFrame-CornerBottomRight" },
		TopEdge           = { atlas = "_MetalFrame-EdgeTop" },
		BottomEdge        = { atlas = "_MetalFrame-EdgeBottom" },
		LeftEdge          = { atlas = "!MetalFrame-EdgeLeft" },
		RightEdge         = { atlas = "!MetalFrame-EdgeRight" }
	},

	PortraitFrameTemplate                    = {
		TopLeftCorner     = { layer = "OVERLAY", atlas = "UI-Frame-PortraitMetal-CornerTopLeft", x = -13, y = 16 },
		TopRightCorner    = { layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerTopRight", x = 4, y = 16 },
		BottomLeftCorner  = { layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomLeft", x = -13, y = -3 },
		BottomRightCorner = { layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomRight", x = 4, y = -3 },
		TopEdge           = { layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeTop", x = 0, y = 0, x1 = 0, y1 = 0 },
		BottomEdge        = { layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeBottom", x = 0, y = 0, x1 = 0, y1 = 0 },
		LeftEdge          = { layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeLeft", x = 0, y = 0, x1 = 0, y1 = 0 },
		RightEdge         = { layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeRight", x = 0, y = 0, x1 = 0, y1 = 0 }
	},

	InsetFrameTemplate                       = {
		TopLeftCorner     = { subLevel = -5, atlas = "UI-Frame-InnerTopLeft" },
		TopRightCorner    = { subLevel = -5, atlas = "UI-Frame-InnerTopRight" },
		BottomLeftCorner  = { subLevel = -5, atlas = "UI-Frame-InnerBotLeftCorner", x = 0, y = -1 },
		BottomRightCorner = { subLevel = -5, atlas = "UI-Frame-InnerBotRight", x = 0, y = -1 },
		TopEdge           = { subLevel = -5, atlas = "_UI-Frame-InnerTopTile" },
		BottomEdge        = { subLevel = -5, atlas = "_UI-Frame-InnerBotTile" },
		LeftEdge          = { subLevel = -5, atlas = "!UI-Frame-InnerLeftTile" },
		RightEdge         = { subLevel = -5, atlas = "!UI-Frame-InnerRightTile" }
	},

};
