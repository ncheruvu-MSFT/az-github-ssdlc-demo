import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { NavComponent } from './shared/nav.component';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet, NavComponent],
  template: `
    <app-nav />
    <main class="container">
      <router-outlet />
    </main>
  `,
})
export class AppComponent {
  title = 'SSDLC Demo WebApp';
}
