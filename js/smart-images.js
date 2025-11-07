// Smart feature image positioning
document.addEventListener('DOMContentLoaded', function() {
  const featureImages = document.querySelectorAll('.feature-image');
  
  featureImages.forEach(function(img) {
    img.addEventListener('load', function() {
      const aspectRatio = this.naturalWidth / this.naturalHeight;
      const containerAspectRatio = this.offsetWidth / this.offsetHeight;
      
      // Special handling for homepage hero image
      if (this.classList.contains('home-hero')) {
        // Keep cover but zoom out slightly and move down
        this.style.objectFit = 'cover';
        this.style.objectPosition = 'center 30%';
        this.style.transform = 'scale(0.9)';
        return;
      }
      
      // Article images: dynamic positioning based on aspect ratio
      // If image is much wider than container, center vertically
      if (aspectRatio > containerAspectRatio * 1.5) {
        this.style.objectPosition = 'center center';
      }
      // If image is much taller than container, focus on top portion
      else if (aspectRatio < containerAspectRatio * 0.7) {
        this.style.objectPosition = 'center 30%';
      }
      // Default: slight focus toward center-top for most images
      else {
        this.style.objectPosition = 'center 40%';
      }
    });
    
    // Trigger load event if image is already cached
    if (img.complete) {
      img.dispatchEvent(new Event('load'));
    }
  });
});
